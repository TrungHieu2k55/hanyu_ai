import 'package:flutter/foundation.dart';
import 'package:doanchuyennganh2/features/admin/data/csv_file_source.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';
import 'package:doanchuyennganh2/features/admin/data/vocabulary_csv_parser.dart';

enum PreviewImportStep { source, mapping, validation, confirmation, result }

class PreviewVocabularyImportController extends ChangeNotifier {
  PreviewVocabularyImportController({
    required Set<String> existing,
    this._fileSource = const LocalCsvFileSource(),
    this._parser = const VocabularyCsvParser(),
  }) : _existing = Set.unmodifiable(existing);
  static const sample =
      'hanzi,pinyin,vietnamese\n早上,zǎoshang,buổi sáng\n晚上,wǎnshang,buổi tối';
  final Set<String> _existing;
  final CsvFileSource _fileSource;
  final VocabularyCsvParser _parser;
  String content = sample;
  String? fileName, error;
  PreviewImportStep step = PreviewImportStep.source;
  CsvTable? table;
  VocabularyImportReport? report;
  final mapping = [0, 1, 2];
  bool picking = false, skipInvalid = false, committed = false;
  bool _disposed = false;
  bool get dirty =>
      !committed && (content != sample || step != PreviewImportStep.source);
  bool get canConfirm =>
      report != null &&
      report!.drafts.isNotEmpty &&
      (report!.issues.isEmpty || skipInvalid);

  void updateContent(String value) {
    content = value;
    error = null;
    table = null;
    report = null;
    step = PreviewImportStep.source;
    skipInvalid = false;
    notifyListeners();
  }

  Future<void> pickFile() async {
    if (picking) return;
    picking = true;
    error = null;
    notifyListeners();
    try {
      final file = await _fileSource.pick();
      if (_disposed) return;
      if (file != null) {
        content = file.content;
        fileName = file.name;
        table = null;
        report = null;
        step = PreviewImportStep.source;
        skipInvalid = false;
      }
    } on CsvImportProblem catch (problem) {
      if (!_disposed) error = problem.message;
    } on Exception {
      if (!_disposed) error = 'Không mở được tệp. Hãy chọn lại hoặc dán CSV.';
    } finally {
      if (!_disposed) {
        picking = false;
        notifyListeners();
      }
    }
  }

  void parse() {
    try {
      table = _parser.parse(content);
      mapping.setAll(0, [0, 1, 2]);
      report = null;
      skipInvalid = false;
      step = PreviewImportStep.mapping;
      error = null;
    } on CsvImportProblem catch (problem) {
      error = problem.message;
    }
    notifyListeners();
  }

  void setColumn(int field, int column) {
    mapping[field] = column;
    report = null;
    skipInvalid = false;
    error = null;
    notifyListeners();
  }

  void validate() {
    if (table == null) return;
    try {
      report = _parser.validate(
        table!,
        VocabularyColumnMapping(
          hanzi: mapping[0],
          pinyin: mapping[1],
          vietnamese: mapping[2],
        ),
        _existing,
      );
      step = PreviewImportStep.validation;
      error =
          report!.issues.any((i) => i.code == ImportIssueCode.duplicateExisting)
          ? 'Có Hán tự/Pinyin đã tồn tại trong bảng mẫu. Không tự ghi đè; quay lại sửa CSV.'
          : null;
    } on CsvImportProblem catch (problem) {
      error = problem.message;
    }
    notifyListeners();
  }

  void setSkipInvalid(bool value) {
    skipInvalid = value;
    notifyListeners();
  }

  void next() {
    if (!canConfirm) return;
    if (step == PreviewImportStep.validation) {
      step = PreviewImportStep.confirmation;
    } else if (step == PreviewImportStep.confirmation) {
      step = PreviewImportStep.result;
    }
    notifyListeners();
  }

  void back() {
    if (step.index > 0 && !committed) {
      step = PreviewImportStep.values[step.index - 1];
      error = null;
      notifyListeners();
    }
  }

  List<VocabularyDraft>? complete() {
    if (committed || step != PreviewImportStep.result || !canConfirm) {
      return null;
    }
    committed = true;
    notifyListeners();
    return report!.drafts;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
