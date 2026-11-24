import '../domain/local_csv_import.dart';
import '../domain/content_payload.dart';

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';

/// Structural CSV validation only. It does not approve language or licensing.
class VocabularyCsvParser {
  const VocabularyCsvParser({this.existingLabel = 'bảng mẫu'});
  final String existingLabel;
  static const maxBytes = maxCsvBytes;
  static const maxRecords = maxCsvRows;

  CsvTable parse(String input) {
    if (utf8.encode(input).length > maxBytes) {
      throw const CsvImportProblem('CSV vượt giới hạn 512 KB.');
    }
    final text = (input.startsWith('\ufeff') ? input.substring(1) : input)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (text.trim().isEmpty) throw const CsvImportProblem('CSV đang trống.');
    late final List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
        allowInvalid: false,
      ).convert(text);
    } on FormatException {
      throw const CsvImportProblem(
        'CSV sai cấu trúc dấu nháy hoặc dấu phân cách. Kiểm tra tệp rồi thử lại.',
      );
    }
    if (rows.length < 2) {
      throw const CsvImportProblem(
        'Cần một hàng tiêu đề và ít nhất một bản ghi.',
      );
    }
    final headers = rows.first.map((cell) => cell.toString().trim()).toList();
    if (headers.length < 3 ||
        headers.length > 12 ||
        headers.any((v) => v.isEmpty) ||
        headers.map((v) => v.toLowerCase()).toSet().length != headers.length) {
      throw const CsvImportProblem(
        'Cần 3–12 cột có tên khác nhau, không để trống tiêu đề.',
      );
    }
    final records = <CsvRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i].map((cell) => cell?.toString() ?? '').toList();
      if (cells.every((cell) => cell.trim().isEmpty)) continue;
      records.add(CsvRecord(i + 1, List.unmodifiable(cells)));
    }
    if (records.isEmpty || records.length > maxRecords) {
      throw const CsvImportProblem('CSV cần có 1–1000 bản ghi dữ liệu.');
    }
    return CsvTable(List.unmodifiable(headers), List.unmodifiable(records));
  }

  VocabularyImportReport validate(
    CsvTable table,
    VocabularyColumnMapping mapping,
    Set<String> existing,
  ) {
    if (mapping.indices.toSet().length != 3 ||
        mapping.indices.any((i) => i < 0 || i >= table.headers.length)) {
      throw const CsvImportProblem('Mỗi trường phải dùng một cột khác nhau.');
    }
    final drafts = <VocabularyDraft>[], issues = <ImportIssue>[];
    final seen = <String>{};
    final known = existing.map(normalizeVocabularyKey).toSet();
    for (final row in table.records) {
      if (row.cells.length != table.headers.length) {
        issues.add(
          ImportIssue(
            row.number,
            'Số cột',
            'Số ô không khớp hàng tiêu đề.',
            ImportIssueCode.columns,
          ),
        );
        continue;
      }
      final values = mapping.indices.map((i) => row.cells[i].trim()).toList();
      final startIssues = issues.length;
      for (var i = 0; i < 3; i++) {
        if (values[i].isEmpty) {
          issues.add(
            ImportIssue(
              row.number,
              ['Hán tự', 'Pinyin', 'Nghĩa Việt'][i],
              'Không được để trống.',
              ImportIssueCode.required,
            ),
          );
        }
      }
      for (var i = 0; i < 3; i++) {
        if (values[i].runes.length > [30, 300, 300][i]) {
          issues.add(
            ImportIssue(
              row.number,
              ['Hán tự', 'Pinyin', 'Nghĩa Việt'][i],
              'Vượt giới hạn ${[30, 300, 300][i]} ký tự.',
              ImportIssueCode.limit,
            ),
          );
        }
      }
      if (values[0].isNotEmpty &&
          !values[0].runes.any(
            (r) =>
                (r >= 0x3400 && r <= 0x9fff) ||
                (r >= 0xf900 && r <= 0xfaff) ||
                (r >= 0x20000 && r <= 0x3134f),
          )) {
        issues.add(
          ImportIssue(
            row.number,
            'Hán tự',
            'Cần có ít nhất một chữ Hán.',
            ImportIssueCode.hanzi,
          ),
        );
      }
      if (issues.length != startIssues) continue;
      final payload = VocabularyContent(
        hanzi: values[0],
        pinyin: values[1],
        vietnamese: values[2],
      );
      final key = vocabularyKey(payload.hanzi, payload.pinyin);
      if (known.contains(key)) {
        issues.add(
          ImportIssue(
            row.number,
            'Hán tự/Pinyin',
            'Đã tồn tại trong $existingLabel; không ghi đè.',
            ImportIssueCode.duplicateExisting,
          ),
        );
      } else if (!seen.add(key)) {
        issues.add(
          ImportIssue(
            row.number,
            'Hán tự/Pinyin',
            'Trùng bản ghi trong CSV.',
            ImportIssueCode.duplicateInFile,
          ),
        );
      } else {
        drafts.add(VocabularyDraft(values[0], values[1], values[2]));
      }
    }
    return VocabularyImportReport(
      List.unmodifiable(drafts),
      List.unmodifiable(issues),
    );
  }
}
