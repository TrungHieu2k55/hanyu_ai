import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';
import 'package:doanchuyennganh2/features/admin/data/vocabulary_csv_parser.dart';

class PickedCsv {
  const PickedCsv(this.name, this.content);
  final String name, content;
}

abstract interface class CsvFileSource {
  Future<PickedCsv?> pick();
}

class LocalCsvFileSource implements CsvFileSource {
  const LocalCsvFileSource();
  @override
  Future<PickedCsv?> pick() async {
    const types = XTypeGroup(
      label: 'CSV',
      extensions: ['csv'],
      mimeTypes: ['text/csv', 'text/plain'],
      uniformTypeIdentifiers: [
        'public.comma-separated-values-text',
        'public.text',
      ],
    );
    final file = await openFile(acceptedTypeGroups: [types]);
    if (file == null) return null;
    if (await file.length() > VocabularyCsvParser.maxBytes) {
      throw const CsvImportProblem('Tệp vượt giới hạn 512 KB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > VocabularyCsvParser.maxBytes) {
      throw const CsvImportProblem('Tệp vượt giới hạn 512 KB.');
    }
    try {
      return PickedCsv(file.name, utf8.decode(bytes));
    } on FormatException {
      throw const CsvImportProblem(
        'Tệp không phải UTF-8 hợp lệ. Hãy lưu CSV dạng UTF-8 rồi chọn lại.',
      );
    }
  }
}
