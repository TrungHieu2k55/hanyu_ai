import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/features/exam/domain/sample_question.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/chat_session.dart';
import 'package:doanchuyennganh2/features/roleplay/data/sample_scenarios.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';
import 'package:doanchuyennganh2/features/admin/data/vocabulary_csv_parser.dart';
import 'package:doanchuyennganh2/features/admin/application/preview_vocabulary_import_controller.dart';
import 'package:doanchuyennganh2/features/admin/data/csv_file_source.dart';

class FixedCsvSource implements CsvFileSource {
  const FixedCsvSource(this.file);
  final PickedCsv? file;
  @override
  Future<PickedCsv?> pick() async => file;
}

void main() {
  const questions = [
    SampleQuestion('一?', ['một', 'hai'], 0, '一: một'),
    SampleQuestion('二?', ['một', 'hai'], 1, '二: hai'),
  ];
  group('Local exam rules', () {
    test('scores selected answers and freezes after submission', () {
      final attempt = ExamAttempt(1, 1, questions: questions);
      expect(attempt.selectAnswer(0, 0), isTrue);
      expect(attempt.selectAnswer(1, 0), isTrue);
      expect(attempt.correct, 1);
      expect(attempt.blanks, 0);
      attempt.finish();
      expect(attempt.selectAnswer(1, 1), isFalse);
      expect(attempt.correct, 1);
      expect(() => attempt.answers[0] = 1, throwsUnsupportedError);
    });
    test(
      'deadline rejects late input and remains timed out on repeat submit',
      () {
        var now = DateTime.utc(2026, 11, 16, 8);
        final attempt = ExamAttempt(
          1,
          1,
          questions: questions,
          clock: () => now,
        );
        now = now.add(const Duration(minutes: 20));
        expect(attempt.selectAnswer(0, 0), isFalse);
        expect(attempt.done, isTrue);
        expect(attempt.timedOut, isTrue);
        attempt.finish();
        expect(attempt.timedOut, isTrue);
      },
    );
    test('a fraction of a second before deadline is still answerable', () {
      var now = DateTime.utc(2026, 11, 16, 8);
      final attempt = ExamAttempt(1, 1, questions: questions, clock: () => now);
      now = attempt.deadline.subtract(const Duration(milliseconds: 1));
      expect(attempt.selectAnswer(0, 0), isTrue);
      expect(attempt.remainingSeconds, 1);
    });
  });
  test('chat confirmation is bounded and ending clears only the draft', () {
    final chat = ChatSession(1, sampleScenarios.first);
    expect(chat.confirmTurn('   '), isFalse);
    for (var i = 0; i < 8; i++) {
      expect(chat.confirmTurn('你好 $i'), isTrue);
    }
    expect(chat.ended, isTrue);
    expect(chat.confirmTurn('ninth'), isFalse);
    expect(chat.turns.length, 8);
    expect(() => chat.turns.clear(), throwsUnsupportedError);
    final unfinished = ChatSession(2, sampleScenarios.first)
      ..confirmTurn('你好')
      ..draft = 'draft';
    unfinished.end();
    expect(unfinished.draft, isEmpty);
    expect(unfinished.turns.length, 1);
  });
  group('CSV validation', () {
    const parser = VocabularyCsvParser();
    const mapping = VocabularyColumnMapping(hanzi: 0, pinyin: 1, vietnamese: 2);
    test(
      'supports BOM, CRLF, quoted commas, quoted newlines and escaped quotes',
      () {
        final table = parser.parse(
          '\ufeffhanzi,pinyin,vietnamese\r\n你好,nǐ hǎo,"xin chào, bạn"\r\n学习,xuéxí,"học\r\ntập ""mới"""',
        );
        final report = parser.validate(table, mapping, {});
        expect(report.issues, isEmpty);
        expect(report.drafts.length, 2);
        expect(report.drafts.first.vietnamese, 'xin chào, bạn');
        expect(report.drafts.last.vietnamese, 'học\ntập "mới"');
      },
    );
    test('reports separate row issues and never silently overwrites existing words', () {
      final table = parser.parse(
        'h,p,v\n你好,nǐ hǎo,xin chào\n早上,,buổi sáng\nabc,abc,text\n晚上,wǎnshang,buổi tối\n晚上,wǎnshang,trùng',
      );
      final report = parser.validate(table, mapping, {'你好|nǐ hǎo'});
      expect(report.drafts.single.hanzi, '晚上');
      expect(report.rejectedRecords, 4);
      expect(report.issues.map((i) => i.record).toSet(), {2, 3, 4, 6});
    });
    test('rejects broken header, unclosed quotes and ambiguous mapping', () {
      expect(
        () => parser.parse('h,h,v\n早上,zǎoshang,sáng'),
        throwsA(isA<CsvImportProblem>()),
      );
      expect(
        () => parser.parse('h,p,v\n早上,zǎoshang,"sáng'),
        throwsA(isA<CsvImportProblem>()),
      );
      final table = parser.parse('h,p,v\n早上,zǎoshang,sáng');
      expect(
        () => parser.validate(
          table,
          const VocabularyColumnMapping(hanzi: 0, pinyin: 0, vietnamese: 2),
          {},
        ),
        throwsA(isA<CsvImportProblem>()),
      );
    });
    test(
      'controller requires explicit partial import and commits only once',
      () {
        final controller = PreviewVocabularyImportController(existing: {})
          ..updateContent('h,p,v\n早上,zǎoshang,sáng\n晚上,,tối')
          ..parse()
          ..validate();
        addTearDown(controller.dispose);
        expect(controller.canConfirm, isFalse);
        expect(controller.complete(), isNull);
        controller.setSkipInvalid(true);
        controller.next();
        controller.next();
        expect(controller.complete()!.length, 1);
        expect(controller.complete(), isNull);
      },
    );
    test('file cancellation preserves draft; choosing a file updates its name/content', () async {
      final cancelled = PreviewVocabularyImportController(
        existing: {},
        fileSource: const FixedCsvSource(null),
      )..updateContent('my draft');
      addTearDown(cancelled.dispose);
      await cancelled.pickFile();
      expect(cancelled.content, 'my draft');
      final imported = PreviewVocabularyImportController(
        existing: {},
        fileSource: const FixedCsvSource(
          PickedCsv('words.csv', 'h,p,v\n早上,zǎoshang,sáng'),
        ),
      );
      addTearDown(imported.dispose);
      await imported.pickFile();
      expect(imported.fileName, 'words.csv');
      imported.parse();
      imported.validate();
      expect(imported.canConfirm, isTrue);
    });
  });
}
