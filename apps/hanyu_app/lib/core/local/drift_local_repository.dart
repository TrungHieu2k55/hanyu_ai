import '../../features/extended_learning/study_preview.dart';
import '../../features/content/application/learning_catalog.dart';
import '../../features/content/domain/content_package.dart';
import '../../features/content/domain/installed_catalog.dart';
import 'learning_catalog_store.dart';
import '../files/local_file_transfer.dart';
import '../../features/support/domain/local_feedback.dart';
import 'feedback_store.dart';

import 'package:crypto/crypto.dart';

import '../../features/practice/domain/local_practice.dart';
import 'practice_store.dart';
import 'practice_archive.dart';
import 'practice_validation.dart';

import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';

import 'exam_store.dart';

import 'package:doanchuyennganh2/features/review/domain/sm2.dart';

import 'review_store.dart';

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';

import 'local_database.dart';
import 'local_commit.dart';
import '../../features/profile/domain/local_profile.dart';
import 'local_models.dart';
import 'local_repository.dart';

class DriftLocalRepository implements LocalRepository {
  DriftLocalRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  late final reviews = ReviewStore(db, clock);
  late final exams = ExamStore(db, clock);
  final LocalDatabase db;
  late final catalogStore = LearningCatalogStore(db);
  late final practice = PracticeStore(db, clock);
  late final feedbackStore = FeedbackStore(db, clock);

  Future<String?> _meta(String key) async => (await (db.select(
    db.localMetadata,
  )..where((m) => m.key.equals(key))).getSingleOrNull())?.value;
  Future<void> _setMeta(String key, String value) => db
      .into(db.localMetadata)
      .insertOnConflictUpdate(
        LocalMetadataCompanion.insert(key: key, value: value),
      );

  static const _studyKey = 'expanded-study-v1';

  @override
  Future<StudyPreview> loadStudyPreview() async {
    final raw = await _meta(_studyKey);
    return raw == null
        ? const StudyPreview()
        : StudyPreview.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<StudyPreview> updateStudyPreview(
    StudyPreview Function(StudyPreview) change,
  ) => db.transaction(() async {
    final next = change(await loadStudyPreview());
    await _setMeta(_studyKey, jsonEncode(next.toJson()));
    return next;
  });

  Future<void> _seed() => db.transaction(() async {
    if (await _meta('seed') != null) return;
    for (final word in sampleVocabulary) {
      await db
          .into(db.localWords)
          .insert(_row(word), mode: InsertMode.insertOrIgnore);
    }
    await _setMeta('seed', 'sample-v1-unreviewed');
    await _setMeta('revision', '0');
    await _setMeta(
      'preferences',
      jsonEncode({'name': '', 'level': 1, 'minutes': 15, 'sound': true}),
    );
  });

  LocalWordsCompanion _row(VocabularyItem word) => LocalWordsCompanion.insert(
    id: word.id,
    hanzi: word.hanzi.trim(),
    pinyin: word.pinyin.trim(),
    meaning: word.vietnamese.trim(),
    personal: word.personal,
    exampleHanzi: Value(word.exampleHanzi),
    exampleVietnamese: Value(word.exampleVietnamese),
  );

  Future<LocalSnapshot> _snapshot() async {
    final rows = await (db.select(
      db.localWords,
    )..orderBy([(w) => OrderingTerm.asc(w.id)])).get();
    final p = jsonDecode((await _meta('preferences'))!) as Map<String, dynamic>;
    final catalog = await catalogStore.load();
    final managed = LearningCatalogStore.definitions(catalog);
    final samples = {for (final word in sampleVocabulary) word.id: word};
    return LocalSnapshot(
      catalog: catalog,
      words: rows
          .map(
            (w) => LocalWord(
              managed[w.id] == null
                  ? VocabularyItem(
                      id: w.id,
                      level: w.personal ? null : samples[w.id]?.level,
                      partOfSpeech: w.personal
                          ? null
                          : samples[w.id]?.partOfSpeech,
                      hanzi: w.hanzi,
                      pinyin: w.pinyin,
                      vietnamese: w.meaning,
                      exampleHanzi: w.exampleHanzi,
                      exampleVietnamese: w.exampleVietnamese,
                      personal: w.personal,
                    )
                  : LearningCatalogStore.word(managed[w.id]!),
              contentRevision: managed[w.id]?.record.revision,
              retained: catalog.retainedWords.containsKey(w.id),
              saved: w.saved,
              note: w.note,
            ),
          )
          .toList(),
      preferences: LocalPreferences(
        name: p['name'] as String,
        level: p['level'] as int,
        minutes: p['minutes'] as int,
        sound: p['sound'] as bool,
      ),
      helpVersionSeen: await _meta('helpVersionSeen'),
      feedback: await feedbackStore.load(),
      revision: int.parse((await _meta('revision'))!),
      review: await reviews.load(),
      exams: await exams.load(),
      practice: List.unmodifiable(await practice.load()),
      media: List.unmodifiable(await practice.mediaInfo()),
    );
  }

  @override
  Future<LocalSnapshot> load() async {
    await _seed();
    return db.transaction(() async {
      await reviews.initializeMissing();
      if (await exams.expireDue() > 0) {
        await _setMeta(
          'revision',
          '${int.parse((await _meta('revision'))!) + 1}',
        );
      }
      return _snapshot();
    });
  }

  Future<LocalSnapshot> _commit(
    int revision,
    String operationId,
    Object payload,
    Future<void> Function() action,
  ) => LocalCommit(db).run(
    revision: revision,
    operationId: operationId,
    payload: payload,
    action: action,
    snapshot: _snapshot,
  );

  @override
  Future<CatalogInstallPreview> preparePackageInstall(
    LocalJsonFile file,
  ) async {
    await _seed();
    return db.transaction(
      () async =>
          catalogStore.prepare(file, int.parse((await _meta('revision'))!)),
    );
  }

  @override
  Future<LocalSnapshot> installPackage(
    CatalogInstallPreview preview, {
    required String operationId,
    bool acceptTrial = false,
    bool activate = false,
  }) async {
    if (preview.package.mode == PackageMode.trial && !acceptTrial) {
      throw const LocalDataException(
        'Xác nhận trước khi cài gói dùng thử có thể chưa được duyệt.',
      );
    }
    final package = preview.package;
    return _commit(preview.baseRevision, operationId, [
      'catalog-install',
      package.publisherId,
      package.packageId,
      package.version,
      package.checksum,
      activate,
    ], () => catalogStore.install(preview, activate: activate));
  }

  @override
  Future<LocalSnapshot> activatePackage(
    String? id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'catalog-activate',
    id,
  ], () => catalogStore.activate(id));

  @override
  Future<LocalSnapshot> removePackage(
    String id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'catalog-remove',
    id,
  ], () => catalogStore.remove(id));

  Future<StoredWord> _require(String id) async {
    final row = await (db.select(
      db.localWords,
    )..where((w) => w.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const LocalDataException(
        'Không tìm thấy từ. Hãy tải lại danh sách.',
      );
    }
    return row;
  }

  @override
  Future<LocalSnapshot> putWord(
    VocabularyItem word, {
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    [
      'word',
      word.id,
      word.hanzi,
      word.pinyin,
      word.vietnamese,
      word.exampleHanzi,
      word.exampleVietnamese,
    ],
    () async {
      if (!word.personal ||
          !word.id.startsWith('personal:') ||
          word.hanzi.trim().isEmpty ||
          word.hanzi.runes.length > 30 ||
          word.pinyin.trim().isEmpty ||
          word.pinyin.length > 300 ||
          word.vietnamese.trim().isEmpty ||
          word.vietnamese.length > 300 ||
          !RegExp(r'[\u3400-\u9fff]').hasMatch(word.hanzi)) {
        throw const LocalDataException(
          'Kiểm tra Hán tự, Pinyin và nghĩa Việt của từ riêng.',
        );
      }
      final all = await db.select(db.localWords).get();
      if (all.any(
        (w) =>
            w.personal &&
            w.id != word.id &&
            w.hanzi == word.hanzi.trim() &&
            w.pinyin.toLowerCase() == word.pinyin.trim().toLowerCase(),
      )) {
        throw const LocalDataException(
          'Từ riêng với Hán tự và Pinyin này đã có.',
        );
      }
      final current = await (db.select(
        db.localWords,
      )..where((w) => w.id.equals(word.id))).getSingleOrNull();
      if (current != null && !current.personal) {
        throw const LocalDataException('Không sửa học liệu chung.');
      }
      if (current == null) {
        await db.into(db.localWords).insert(_row(word));
      } else {
        await (db.update(
          db.localWords,
        )..where((w) => w.id.equals(word.id))).write(_row(word));
      }
    },
  );

  @override
  Future<LocalSnapshot> saveWord(
    String id,
    bool saved, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['saved', id, saved], () async {
    await _require(id);
    await (db.update(db.localWords)..where((w) => w.id.equals(id))).write(
      LocalWordsCompanion(saved: Value(saved)),
    );
    await reviews.setSaved(id, saved);
  });
  @override
  Future<LocalSnapshot> saveNote(
    String id,
    String note, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['note', id, note], () async {
    await _require(id);
    if (note.length > 2000) {
      throw const LocalDataException('Ghi chú tối đa 2.000 ký tự.');
    }
    await (db.update(db.localWords)..where((w) => w.id.equals(id))).write(
      LocalWordsCompanion(note: Value(note)),
    );
  });
  @override
  Future<LocalSnapshot> deleteWord(
    String id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['delete', id], () async {
    if (!(await _require(id)).personal) {
      throw const LocalDataException('Không xóa học liệu chung.');
    }
    await (db.delete(db.localWords)..where((w) => w.id.equals(id))).go();
  });
  @override
  Future<LocalSnapshot> savePreferences(
    LocalPreferences p, {
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    ['preferences', p.name, p.level, p.minutes, p.sound],
    () async {
      final normalized = LocalProfile.fromPreferences(p).validated();
      await _setMeta(
        'preferences',
        jsonEncode({
          'name': normalized.name,
          'level': p.level,
          'minutes': p.minutes,
          'sound': p.sound,
        }),
      );
    },
  );

  @override
  Future<LocalSnapshot> saveProfile(
    LocalProfile profile, {
    required int revision,
    required String operationId,
  }) => savePreferences(
    profile.toPreferences(),
    revision: revision,
    operationId: operationId,
  );

  @override
  Future<LocalSnapshot> saveHelpSeen(
    String version, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['help-seen', version], () async {
    LocalProfile(helpVersionSeen: version).validated();
    await _setMeta('helpVersionSeen', version);
  });

  @override
  Future<LocalSnapshot> startReview({
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['review-start'], reviews.start);
  @override
  Future<LocalSnapshot> revealReview(
    String id,
    int position, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'review-reveal',
    id,
    position,
  ], () => reviews.reveal(id, position));
  @override
  Future<LocalSnapshot> rateReview(
    String id,
    int position,
    MemoryRating rating, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'review-rate',
    id,
    position,
    rating.quality,
  ], () => reviews.rate(id, position, rating));

  @override
  Future<LocalSnapshot> startExam(
    String packageId,
    LocalExamMode mode, {
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    ['exam-start', packageId, mode.name],
    () async => exams.start(
      packageId,
      mode,
      activePackages: catalogExams(await catalogStore.load()),
    ),
  );
  @override
  Future<LocalSnapshot> saveExamAnswer(
    String id,
    int index,
    int? choice, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'exam-answer',
    id,
    index,
    choice,
  ], () => exams.answer(id, index, choice));
  @override
  Future<LocalSnapshot> moveExam(
    String id,
    int index, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'exam-move',
    id,
    index,
  ], () => exams.move(id, index));
  @override
  Future<LocalSnapshot> submitExam(
    String id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'exam-submit',
    id,
  ], () => exams.submit(id));

  @override
  Future<LocalSnapshot> savePractice(
    LocalPracticeEntry entry, {
    List<LocalMediaInput> media = const [],
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'practice-save',
    entry.toJson(),
    for (final m in media) [m.id, m.mime, sha256.convert(m.bytes).toString()],
  ], () => practice.save(entry, media));
  @override
  Future<LocalSnapshot> confirmPracticeTurn(
    String id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'practice-confirm',
    id,
  ], () => practice.confirmTurn(id));
  @override
  Future<LocalSnapshot> deletePractice(
    String id, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'practice-delete',
    id,
  ], () => practice.delete(id));
  @override
  Future<Uint8List?> readMedia(String id) => practice.readMedia(id);
  @override
  Future<LocalSnapshot> restoreArchive(
    Uint8List bytes, {
    required int revision,
    required String operationId,
  }) async {
    try {
      if (bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4b) {
        final archive = PracticeArchive.decode(bytes);
        return await _restoreData(
          archive.data,
          sha256.convert(bytes).toString(),
          archive.media,
          revision: revision,
          operationId: operationId,
        );
      }
      return await restoreBackup(
        utf8.decode(bytes),
        revision: revision,
        operationId: operationId,
      );
    } on LocalDataException {
      rethrow;
    } catch (_) {
      throw const LocalDataException(
        'Backup hỏng hoặc không đúng định dạng. Dữ liệu hiện tại được giữ nguyên.',
      );
    }
  }

  @override
  Future<Uint8List> exportArchive() => db.transaction(() async {
    final snapshot = await load();
    final data = await _backupData(snapshot);
    data['version'] = 5;
    data['catalog'] = snapshot.catalog.toJson();
    data['helpVersionSeen'] = snapshot.helpVersionSeen;
    data['feedback'] = snapshot.feedback.map((r) => r.toJson()).toList();
    data['feedbackPins'] = await feedbackStore.exportPins();
    data['practice'] = [for (final e in await practice.load()) e.toJson()];
    final media = <LocalMediaInput>[];
    for (final m in await practice.mediaInfo()) {
      media.add(
        LocalMediaInput(
          id: m.id,
          mime: m.mime,
          bytes: (await practice.readMedia(m.id))!,
        ),
      );
    }
    return PracticeArchive.encode(data, media);
  });
  @override
  Future<String> exportBackup() => db.transaction(() async {
    final snapshot = await load();
    if (snapshot.catalog.receiptHistory.isNotEmpty) {
      throw const LocalDataException(
        'Dùng backup ZIP để giữ gói học liệu và nguồn từ.',
      );
    }
    return jsonEncode(await _backupData(snapshot));
  });

  Future<Map<String, dynamic>> _backupData(LocalSnapshot s) async => {
    'format': 'hanyu-local',
    'version': 3,
    'seed': 'sample-v1-unreviewed',
    'preferences': {
      'name': s.preferences.name,
      'level': s.preferences.level,
      'minutes': s.preferences.minutes,
      'sound': s.preferences.sound,
    },
    'review': await reviews.export(),
    'exams': await exams.export(),
    'words': [
      for (final w in s.words)
        {
          'id': w.entry.id,
          'hanzi': w.entry.hanzi,
          'pinyin': w.entry.pinyin,
          'meaning': w.entry.vietnamese,
          'personal': w.entry.personal,
          'saved': w.saved,
          'note': w.note,
          'exampleHanzi': w.entry.exampleHanzi,
          'exampleVietnamese': w.entry.exampleVietnamese,
        },
    ],
  };

  @override
  Future<LocalSnapshot> restoreBackup(
    String source, {
    required int revision,
    required String operationId,
  }) async {
    if (utf8.encode(source).length > 10 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt 10 MB.');
    }
    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(source) as Map<String, dynamic>;
    } catch (_) {
      throw const LocalDataException('Không đọc được JSON backup.');
    }
    if (data['version'] == 4 || data['version'] == 5) {
      throw const LocalDataException('Backup v4/v5 phải là ZIP kèm manifest.');
    }
    return _restoreData(
      data,
      sha256.convert(utf8.encode(source)).toString(),
      const [],
      revision: revision,
      operationId: operationId,
    );
  }

  Future<LocalSnapshot> _restoreData(
    Map<String, dynamic> data,
    String fingerprint,
    List<LocalMediaInput> media, {
    required int revision,
    required String operationId,
  }) async {
    if (data['format'] != 'hanyu-local' ||
        (data['version'] is! int ||
            ![1, 2, 3, 4, 5].contains(data['version'])) ||
        data['seed'] != 'sample-v1-unreviewed' ||
        data['words'] is! List ||
        (data['words'] as List).length > 10000) {
      throw const LocalDataException(
        'Backup không đúng định dạng hoặc phiên bản.',
      );
    }
    if (data['version'] >= 2 && data['review'] is! Map<String, dynamic>) {
      throw const LocalDataException('Backup thiếu lịch sử ôn.');
    }
    if (data['version'] >= 3 && data['exams'] is! List) {
      throw const LocalDataException('Backup thiếu bài thi.');
    }
    if (data['version'] >= 4 && data['practice'] is! List) {
      practiceError('Backup thiếu lịch sử thực hành.');
    }
    final rows = <LocalWordsCompanion>[];
    final ids = <String>{};
    final privateKeys = <String>{};
    final hasE = data['version'] == 5;
    final archiveCatalog = hasE
        ? _readArchiveCatalog(data)
        : InstalledCatalog();
    final feedback = hasE ? _readArchiveFeedback(data) : <FeedbackReport>[];
    final pins = <String, String>{};
    String? helpVersion;
    if (hasE) {
      final help = data['helpVersionSeen'];
      if (!data.containsKey('helpVersionSeen') ||
          (help != null && help is! String)) {
        throw const LocalDataException(
          'Marker hướng dẫn trong backup không hợp lệ.',
        );
      }
      helpVersion = LocalProfile(helpVersionSeen: help as String?)
          .validated()
          .helpVersionSeen;
      final rawPins = data['feedbackPins'];
      final validPins = {
        for (final report in feedback.where(
          (r) => r.state != FeedbackState.draft,
        ))
          'feedback-export:${report.id}:${report.revision}': report.checksum,
      };
      if (rawPins is! Map<String, dynamic> ||
          rawPins.entries.any(
            (e) => validPins[e.key] != e.value || e.value is! String,
          )) {
        throw const LocalDataException(
          'Phiên bản báo lỗi đã khóa trong backup không khớp.',
        );
      }
      for (final entry in rawPins.entries) {
        pins[entry.key] = entry.value as String;
      }
    }
    final catalog = {
      for (final word in sampleVocabulary) word.id: word,
      for (final definition in LearningCatalogStore.definitions(
        archiveCatalog,
      ).values)
        definition.id: LearningCatalogStore.word(definition),
    };
    for (final raw in data['words'] as List) {
      if (raw is! Map<String, dynamic> ||
          raw['id'] is! String ||
          !ids.add(raw['id']) ||
          raw['personal'] is! bool ||
          raw['saved'] is! bool ||
          [
            'hanzi',
            'pinyin',
            'meaning',
            'note',
            'exampleHanzi',
            'exampleVietnamese',
          ].any((k) => raw[k] is! String || (raw[k] as String).length > 2000)) {
        throw const LocalDataException(
          'Có bản ghi lỗi hoặc ID trùng trong backup.',
        );
      }
      if ((raw['personal'] as bool) !=
          (raw['id'] as String).startsWith('personal:')) {
        throw const LocalDataException('Nguồn từ trong backup không hợp lệ.');
      }
      if (raw['personal'] as bool) {
        final key =
            '${(raw['hanzi'] as String).trim()}|${(raw['pinyin'] as String).trim().toLowerCase()}';
        if (!privateKeys.add(key) ||
            (raw['id'] as String).length > 100 ||
            (raw['hanzi'] as String).trim().isEmpty ||
            (raw['hanzi'] as String).runes.length > 30 ||
            !RegExp(r'[㐀-鿿]').hasMatch(raw['hanzi']) ||
            (raw['pinyin'] as String).trim().isEmpty ||
            (raw['pinyin'] as String).length > 300 ||
            (raw['meaning'] as String).trim().isEmpty ||
            (raw['meaning'] as String).length > 300) {
          throw const LocalDataException(
            'Có từ riêng lỗi hoặc trùng trong backup.',
          );
        }
      } else {
        final original = catalog[raw['id']];
        if (original == null ||
            original.hanzi != raw['hanzi'] ||
            original.pinyin != raw['pinyin'] ||
            original.vietnamese != raw['meaning'] ||
            original.exampleHanzi != raw['exampleHanzi'] ||
            original.exampleVietnamese != raw['exampleVietnamese']) {
          throw const LocalDataException(
            'Học liệu chung trong backup không khớp phiên bản hiện hành.',
          );
        }
      }
      rows.add(
        LocalWordsCompanion.insert(
          id: raw['id'],
          hanzi: raw['hanzi'],
          pinyin: raw['pinyin'],
          meaning: raw['meaning'],
          personal: raw['personal'],
          saved: Value(raw['saved']),
          note: Value(raw['note']),
          exampleHanzi: Value(raw['exampleHanzi']),
          exampleVietnamese: Value(raw['exampleVietnamese']),
        ),
      );
    }
    if (!catalog.keys.every(ids.contains)) {
      throw const LocalDataException(
        'Backup thiếu dữ liệu từ vựng theo danh mục.',
      );
    }
    final p = data['preferences'];
    if (p is! Map<String, dynamic> ||
        p['name'] is! String ||
        (p['name'] as String).trim().runes.length > 80 ||
        p['level'] is! int ||
        ![1, 2, 3].contains(p['level']) ||
        ![5, 10, 15, 20, 30].contains(p['minutes']) ||
        p['sound'] is! bool) {
      throw const LocalDataException('Thiết lập trong backup không hợp lệ.');
    }
    final preparedReview = reviews.prepareRestore(
      data['version'] == 1 ? null : data['review'] as Map<String, dynamic>,
      {for (final row in rows) row.id.value: row.saved.value},
    );
    final preparedExams = exams.prepareRestore(
      data['version'] >= 3 ? data['exams'] as List : null,
    );
    final preparedPractice = data['version'] >= 4
        ? preparePracticeRestore(data['practice'] as List, media)
        : null;
    return _commit(revision, operationId, ['restore', fingerprint], () async {
      await practice.clear();
      await exams.clear();
      await reviews.clear();
      await db.delete(db.localWords).go();
      await db.batch((b) => b.insertAll(db.localWords, rows));
      await reviews.applyRestore(preparedReview);
      await exams.applyRestore(preparedExams);
      if (preparedPractice != null) {
        await practice.applyRestore(preparedPractice);
      }
      await catalogStore.writeCatalog(archiveCatalog);
      await feedbackStore.replaceFromBackup(feedback, pins);
      await (db.delete(
        db.localMetadata,
      )..where((row) => row.key.equals('helpVersionSeen'))).go();
      if (helpVersion != null) await _setMeta('helpVersionSeen', helpVersion);
      await _setMeta('preferences', jsonEncode(p));
      await db.delete(db.localReceipts).go();
    });
  }

  InstalledCatalog _readArchiveCatalog(Map<String, dynamic> data) {
    final raw = data['catalog'];
    if (raw is! Map<String, dynamic>) {
      throw const LocalDataException('Backup thiếu danh mục gói học liệu.');
    }
    return InstalledCatalog.fromJson(raw);
  }

  List<FeedbackReport> _readArchiveFeedback(Map<String, dynamic> data) {
    final raw = data['feedback'];
    if (raw is! List || raw.length > 1000) {
      throw const LocalDataException(
        'Danh sách báo lỗi trong backup không hợp lệ.',
      );
    }
    final keys = <String>{};
    return [for (final entry in raw) _readArchiveReport(entry, keys)];
  }

  FeedbackReport _readArchiveReport(Object? value, Set<String> keys) {
    if (value is! Map<String, dynamic>) {
      throw const LocalDataException('Báo lỗi trong backup không hợp lệ.');
    }
    final report = FeedbackReport.fromJson(value);
    if (!keys.add('${report.id}:${report.revision}')) {
      throw const LocalDataException('Backup có phiên bản báo lỗi trùng.');
    }
    return report;
  }

  @override
  Future<LocalSnapshot> saveFeedback({
    required String id,
    required int reportRevision,
    required String body,
    FeedbackContext? context,
    bool draft = false,
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    ['feedback-save', id, reportRevision, body, context?.values, draft],
    () => feedbackStore.save(
      id: id,
      reportRevision: reportRevision,
      body: body,
      context: context,
      draft: draft,
    ),
  );
  @override
  Future<LocalSnapshot> prepareFeedbackExport(
    String id,
    int reportRevision, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'feedback-pin',
    id,
    reportRevision,
  ], () => feedbackStore.prepareExport(id, reportRevision));
  @override
  Future<LocalJsonFile> feedbackExportFile(String id, int reportRevision) =>
      db.transaction(() => feedbackStore.exportFile(id, reportRevision));
  @override
  Future<LocalSnapshot> markFeedbackExported(
    String id,
    int reportRevision,
    String checksum, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'feedback-exported',
    id,
    reportRevision,
    checksum,
  ], () => feedbackStore.markExported(id, reportRevision, checksum));
  @override
  Future<FeedbackReceipt> previewFeedbackReceipt(LocalJsonFile file) =>
      db.transaction(() async {
        final receipt = FeedbackReceipt.fromFile(file);
        await feedbackStore.validateReceipt(receipt);
        return receipt;
      });
  @override
  Future<LocalSnapshot> importFeedbackReceipt(
    FeedbackReceipt receipt, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'feedback-result',
    receipt.toJson(),
  ], () => feedbackStore.importReceipt(receipt));

  @override
  Future<void> close() => db.close();
}
