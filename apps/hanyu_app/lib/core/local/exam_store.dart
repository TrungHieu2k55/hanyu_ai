import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/features/exam/data/local_exam_packages.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';

import 'local_database.dart';
import 'local_models.dart';

/// The repository supplies transactions, receipts and revision checks.
class ExamStore {
  ExamStore(this.db, this.clock, {List<LocalExamPackage>? packages})
    : packages = List.unmodifiable(packages ?? localExamPackages);
  final LocalDatabase db;
  final DateTime Function() clock;
  final List<LocalExamPackage> packages;

  List<LocalExamQuestion> _questions(String json) => (jsonDecode(json) as List)
      .map((q) => LocalExamQuestion.fromJson(q as Map<String, dynamic>))
      .toList();
  Map<int, int> _answers(String json, List<LocalExamQuestion> questions) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final answers = {
      for (final entry in raw.entries) int.parse(entry.key): entry.value as int,
    };
    gradeLocalExam(questions, answers);
    return answers;
  }

  LocalExamAttempt _read(StoredExamAttempt row) {
    final questions = _questions(row.questionsJson);
    return LocalExamAttempt(
      id: row.id,
      packageId: row.packageId,
      packageVersion: row.packageVersion,
      targetLevel: row.targetLevel,
      mode: LocalExamMode.values.byName(row.mode),
      questions: questions,
      answers: _answers(row.answersJson, questions),
      position: row.position,
      startedAt: row.startedAt.toUtc(),
      deadline: row.deadline.toUtc(),
      submittedAt: row.submittedAt?.toUtc(),
      timedOut: row.timedOut,
      correctCount: row.correctCount,
    );
  }

  Future<StoredExamAttempt> _require(String id) async {
    final row = await (db.select(
      db.localExamAttempts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const LocalDataException(
        'Không tìm thấy bài làm. Hãy mở lại danh sách.',
      );
    }
    return row;
  }

  Future<LocalExamState> load() async => LocalExamState(
    attempts: List.unmodifiable([
      for (final row in await (db.select(
        db.localExamAttempts,
      )..orderBy([(a) => OrderingTerm.desc(a.startedAt)])).get())
        _read(row),
    ]),
  );

  Future<void> start(
    String packageId,
    LocalExamMode mode, {
    List<LocalExamPackage>? activePackages,
  }) async {
    LocalExamPackage? pack;
    for (final candidate in activePackages ?? packages) {
      if (candidate.id == packageId) {
        pack = candidate;
        break;
      }
    }
    if (pack == null) throw const LocalDataException('Không tìm thấy bộ đề.');
    if (mode == LocalExamMode.fullExam && !pack.readyForFullExam) {
      throw const LocalDataException(
        'Đề chưa đủ nội dung được duyệt và audio. Chỉ mở xem nháp hoặc luyện đọc.',
      );
    }
    final existing =
        await (db.select(db.localExamAttempts)..where(
              (a) =>
                  a.packageId.equals(packageId) &
                  a.mode.equals(mode.name) &
                  a.submittedAt.isNull(),
            ))
            .get();
    if (existing.isNotEmpty) {
      await _expired(existing.first);
      return;
    }
    final questions = mode == LocalExamMode.readingPractice
        ? pack.questions.where((q) => q.section == ExamSection.reading).toList()
        : pack.questions;
    if ((pack.fromCatalog &&
            mode == LocalExamMode.readingPractice &&
            !pack.readyForReading) ||
        questions.isEmpty ||
        questions.length > 20 ||
        questions.map((q) => q.id).toSet().length != questions.length) {
      throw const LocalDataException('Bộ câu hỏi chưa hợp lệ.');
    }
    final now = clock().toUtc();
    await db
        .into(db.localExamAttempts)
        .insert(
          LocalExamAttemptsCompanion.insert(
            id: const Uuid().v4(),
            packageId: pack.id,
            packageVersion: pack.version,
            targetLevel: pack.targetLevel,
            mode: mode.name,
            questionsJson: jsonEncode(
              questions.map((q) => q.toJson()).toList(),
            ),
            startedAt: now,
            deadline: now.add(const Duration(minutes: 20)),
          ),
        );
  }

  Future<void> _finish(StoredExamAttempt row, {required bool timeout}) async {
    if (row.submittedAt != null) return;
    final questions = _questions(row.questionsJson),
        answers = _answers(row.answersJson, _questions(row.questionsJson));
    final score = gradeLocalExam(questions, answers);
    await (db.update(
      db.localExamAttempts,
    )..where((a) => a.id.equals(row.id))).write(
      LocalExamAttemptsCompanion(
        submittedAt: Value(clock().toUtc()),
        timedOut: Value(timeout),
        correctCount: Value(score),
      ),
    );
  }

  Future<bool> _expired(StoredExamAttempt row) async {
    if (row.submittedAt != null) return true;
    if (!clock().toUtc().isBefore(row.deadline.toUtc())) {
      await _finish(row, timeout: true);
      return true;
    }
    return false;
  }

  Future<int> expireDue() async {
    final rows =
        await (db.select(db.localExamAttempts)..where(
              (a) =>
                  a.submittedAt.isNull() &
                  a.deadline.isSmallerOrEqualValue(clock().toUtc()),
            ))
            .get();
    for (final row in rows) {
      await _finish(row, timeout: true);
    }
    return rows.length;
  }

  Future<void> answer(String id, int index, int? choice) async {
    final row = await _require(id);
    if (await _expired(row)) return;
    final questions = _questions(row.questionsJson);
    if (index < 0 ||
        index >= questions.length ||
        (choice != null &&
            (choice < 0 || choice >= questions[index].choices.length))) {
      throw const LocalDataException('Lựa chọn câu trả lời chưa hợp lệ.');
    }
    final answers = _answers(row.answersJson, questions);
    if (choice == null) {
      answers.remove(index);
    } else {
      answers[index] = choice;
    }
    await (db.update(
      db.localExamAttempts,
    )..where((a) => a.id.equals(id))).write(
      LocalExamAttemptsCompanion(
        answersJson: Value(
          jsonEncode({
            for (final entry in answers.entries) '${entry.key}': entry.value,
          }),
        ),
      ),
    );
  }

  Future<void> move(String id, int index) async {
    final row = await _require(id);
    if (await _expired(row)) return;
    if (index < 0 || index >= _questions(row.questionsJson).length) {
      throw const LocalDataException('Vị trí câu hỏi không hợp lệ.');
    }
    await (db.update(db.localExamAttempts)..where((a) => a.id.equals(id)))
        .write(LocalExamAttemptsCompanion(position: Value(index)));
  }

  Future<void> submit(String id) async {
    final row = await _require(id);
    if (await _expired(row)) return;
    await _finish(row, timeout: false);
  }

  Future<List<Map<String, dynamic>>> export() async => [
    for (final row in await db.select(db.localExamAttempts).get())
      {
        'id': row.id,
        'packageId': row.packageId,
        'packageVersion': row.packageVersion,
        'targetLevel': row.targetLevel,
        'mode': row.mode,
        'questions': jsonDecode(row.questionsJson),
        'answers': jsonDecode(row.answersJson),
        'position': row.position,
        'startedAt': row.startedAt.toUtc().toIso8601String(),
        'deadline': row.deadline.toUtc().toIso8601String(),
        'submittedAt': row.submittedAt?.toUtc().toIso8601String(),
        'timedOut': row.timedOut,
        'correctCount': row.correctCount,
      },
  ];
  Future<void> clear() => db.delete(db.localExamAttempts).go();

  Future<void> restore(List? input) => applyRestore(prepareRestore(input));
  Future<void> applyRestore(List<LocalExamAttemptsCompanion> prepared) =>
      db.batch((b) => b.insertAll(db.localExamAttempts, prepared));
  List<LocalExamAttemptsCompanion> prepareRestore(List? input) {
    if (input == null) return [];
    final prepared = <LocalExamAttemptsCompanion>[];
    try {
      if (input.length > 10000) throw const FormatException();
      final ids = <String>{};
      for (final raw in input) {
        final r = raw as Map<String, dynamic>;
        final id = r['id'] as String;
        final level = r['targetLevel'];
        final mode = LocalExamMode.values.byName(r['mode'] as String);
        final questions = _questions(jsonEncode(r['questions']));
        final answers = _answers(jsonEncode(r['answers']), questions);
        final started = DateTime.parse(r['startedAt']).toUtc(),
            deadline = DateTime.parse(r['deadline']).toUtc();
        final submitted = r['submittedAt'] == null
            ? null
            : DateTime.parse(r['submittedAt']).toUtc();
        final score = r['correctCount'];
        if (id.isEmpty ||
            id.length > 100 ||
            !ids.add(id) ||
            r['packageId'] is! String ||
            (r['packageId'] as String).length > 100 ||
            r['packageVersion'] is! String ||
            (r['packageVersion'] as String).length > 100 ||
            ![1, 2, 3].contains(level) ||
            questions.isEmpty ||
            questions.length > 20 ||
            questions.map((q) => q.id).toSet().length != questions.length ||
            r['position'] is! int ||
            r['position'] < 0 ||
            r['position'] >= questions.length ||
            r['timedOut'] is! bool ||
            deadline.difference(started) != const Duration(minutes: 20) ||
            (mode == LocalExamMode.readingPractice &&
                questions.any((q) => q.section != ExamSection.reading)) ||
            (submitted == null && (score != null || r['timedOut'] == true)) ||
            (submitted != null &&
                (score is! int ||
                    score != gradeLocalExam(questions, answers)))) {
          throw const FormatException();
        }
        prepared.add(
          LocalExamAttemptsCompanion.insert(
            id: id,
            packageId: r['packageId'],
            packageVersion: r['packageVersion'],
            targetLevel: level,
            mode: mode.name,
            questionsJson: jsonEncode(
              questions.map((q) => q.toJson()).toList(),
            ),
            answersJson: Value(
              jsonEncode({
                for (final a in answers.entries) '${a.key}': a.value,
              }),
            ),
            position: Value(r['position']),
            startedAt: started,
            deadline: deadline,
            submittedAt: Value(submitted),
            timedOut: Value(r['timedOut']),
            correctCount: Value(score as int?),
          ),
        );
      }
      return prepared;
    } catch (_) {
      throw const LocalDataException(
        'Bài thi trong backup không hợp lệ. Dữ liệu hiện có vẫn giữ.',
      );
    }
  }
}
