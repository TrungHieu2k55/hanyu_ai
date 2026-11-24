import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local/local_models.dart';
import '../data/csv_file_source.dart';
import '../data/local_admin_repository.dart';
import '../data/vocabulary_csv_parser.dart';
import '../domain/local_admin.dart';
import '../domain/local_csv_import.dart';
import '../domain/vocabulary_import.dart';

enum ImportStep { source, mapping, validation, confirmation, result }

typedef CsvPersist = Future<LocalAdminSnapshot> Function(
  CsvImportPreview preview,
  bool skipInvalid,
  String operationId,
);

/// An accepted database response is the only transition into the result step.
class VocabularyImportController extends ChangeNotifier {
  VocabularyImportController({
    required LocalAdminRepository repository,
    CsvFileSource fileSource = const LocalCsvFileSource(),
    CsvPersist? persist,
  }) : _repository = repository,
       _files = fileSource,
       _persist =
           persist ??
           ((p, skip, op) =>
               repository.commitCsv(p, skipInvalid: skip, operationId: op));
  static const sample =
      'hanzi,pinyin,vietnamese\n早上,zǎoshang,buổi sáng\n晚上,wǎnshang,buổi tối';
  final LocalAdminRepository _repository;
  final CsvFileSource _files;
  final CsvPersist _persist;
  String _content = '';
  String get content => _content;
  String? fileName, error, _operationId;
  ImportStep step = ImportStep.source;
  CsvTable? table;
  CsvImportPreview? preview;
  CsvImportResult? result;
  final _mapping = [0, 1, 2];
  List<int> get mapping => List.unmodifiable(_mapping);
  VocabularyImportReport? get report => preview?.report;
  bool picking = false,
      validating = false,
      committing = false,
      skipInvalid = false,
      committed = false,
      _disposed = false;
  bool get busy => picking || validating || committing;
  bool get dirty =>
      !committed && (_content.isNotEmpty || step != ImportStep.source);
  bool get canConfirm =>
      preview != null &&
      preview!.report.drafts.isNotEmpty &&
      (preview!.report.issues.isEmpty || skipInvalid);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _reset() {
    preview = null;
    result = null;
    skipInvalid = false;
    _operationId = null;
    error = null;
  }

  void updateContent(String value) {
    if (busy || committed) return;
    _content = value;
    fileName = null;
    table = null;
    _reset();
    step = ImportStep.source;
    _notify();
  }

  Future<void> pickFile() async {
    if (busy || committed) return;
    picking = true;
    error = null;
    _notify();
    try {
      final file = await _files.pick();
      if (_disposed) return;
      if (file != null) {
        _content = file.content;
        fileName = file.name;
        table = null;
        _reset();
        step = ImportStep.source;
      }
    } catch (e) {
      if (!_disposed) {
        error = e is CsvImportProblem
            ? e.message
            : 'Không mở được CSV. Nội dung đang soạn vẫn giữ.';
      }
    } finally {
      picking = false;
      _notify();
    }
  }

  void parse() {
    if (busy || committed) return;
    try {
      table = const VocabularyCsvParser().parse(_content);
      _mapping.setAll(0, [0, 1, 2]);
      _reset();
      step = ImportStep.mapping;
    } on CsvImportProblem catch (e) {
      error = e.message;
    }
    _notify();
  }

  void setColumn(int field, int column) {
    if (busy || committed) return;
    if (field < 0 ||
        field > 2 ||
        table == null ||
        column < 0 ||
        column >= table!.headers.length) {
      return;
    }
    _mapping[field] = column;
    _reset();
    _notify();
  }

  Future<void> validate() async {
    if (busy || committed || table == null) return;
    validating = true;
    _reset();
    // No report exists until the asynchronous DB validation returns.
    step = ImportStep.mapping;
    _notify();
    try {
      final value = await _repository.previewCsv(
        _content,
        VocabularyColumnMapping(
          hanzi: _mapping[0],
          pinyin: _mapping[1],
          vietnamese: _mapping[2],
        ),
      );
      if (!_disposed) {
        preview = value;
        step = ImportStep.validation;
      }
    } catch (e) {
      if (!_disposed) {
        error = e is CsvImportProblem
            ? e.message
            : e is LocalDataException
            ? e.message
            : 'Chưa kiểm tra được. CSV và ánh xạ vẫn giữ.';
      }
    } finally {
      validating = false;
      _notify();
    }
  }

  void setSkipInvalid(bool value) {
    if (busy || committed) return;
    skipInvalid = value;
    _operationId = null;
    _notify();
  }

  void next() {
    if (!busy && !committed && step == ImportStep.validation && canConfirm) {
      step = ImportStep.confirmation;
      _notify();
    }
  }

  void back() {
    if (!busy && !committed && step.index > 0 && step != ImportStep.result) {
      step = ImportStep.values[step.index - 1];
      error = null;
      _notify();
    }
  }

  Future<CsvImportResult?> complete() async {
    if (busy || committed || step != ImportStep.confirmation || !canConfirm) {
      return null;
    }
    final prepared = preview!;
    final skip = skipInvalid;
    _operationId ??= const Uuid().v4();
    committing = true;
    error = null;
    _notify();
    try {
      final snapshot = await _persist(prepared, skip, _operationId!);
      final summary = snapshot.imports
          .where((r) => r.operationId == _operationId)
          .firstOrNull;
      if (summary == null) {
        throw const LocalDataException(
          'Chưa tìm thấy kết quả nhập đã lưu. Tải lại lịch sử nhập để kiểm tra.',
        );
      }
      result = summary;
      committed = true;
      step = ImportStep.result;
      return summary;
    } catch (e) {
      error = e is LocalDataException
          ? e.message
          : e is CsvImportProblem
          ? e.message
          : 'Chưa nhận được xác nhận lưu. CSV, ánh xạ và lựa chọn vẫn giữ; thử lại sẽ dùng cùng mã thao tác.';
      return null;
    } finally {
      committing = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
