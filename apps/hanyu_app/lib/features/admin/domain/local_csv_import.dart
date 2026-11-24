import 'dart:convert';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/json_contract.dart';
import '../../../core/local/local_models.dart';
import 'vocabulary_import.dart';

const maxCsvRows = 1000;
const maxCsvBytes = 512 * 1024;
String vocabularyKey(String hanzi, String pinyin) =>
    canonicalJson([hanzi.trim(), pinyin.trim().toLowerCase()]);
String normalizeVocabularyKey(String key) {
  try {
    final decoded = jsonDecode(key);
    if (decoded is List &&
        decoded.length == 2 &&
        decoded.every((v) => v is String)) {
      return vocabularyKey(decoded[0] as String, decoded[1] as String);
    }
  } on FormatException {
    /* Legacy QA uses a pipe-delimited key. */
  }
  final split = key.indexOf('|');
  return split < 0
      ? key
      : vocabularyKey(key.substring(0, split), key.substring(split + 1));
}

Map<String, dynamic> csvReportJson(VocabularyImportReport report) => {
  'drafts': [
    for (final d in report.drafts)
      {'hanzi': d.hanzi, 'pinyin': d.pinyin, 'vietnamese': d.vietnamese},
  ],
  'issues': [
    for (final i in report.issues)
      {
        'record': i.record,
        'field': i.field,
        'message': i.message,
        'code': i.code.name,
      },
  ],
};

class CsvImportPreview {
  CsvImportPreview({
    required this.content,
    required this.mapping,
    required VocabularyImportReport report,
    required this.revision,
  }) : report = VocabularyImportReport(
         List.unmodifiable(report.drafts),
         List.unmodifiable(report.issues),
       ) {
    if (utf8.encode(content).length > maxCsvBytes ||
        revision < 0 ||
        mapping.indices.toSet().length != 3 ||
        mapping.indices.any((v) => v < 0 || v > 11)) {
      throw const LocalDataException('Bản xem trước CSV không hợp lệ.');
    }
  }
  final String content;
  final VocabularyColumnMapping mapping;
  final VocabularyImportReport report;
  final int revision;
  String get inputChecksum => canonicalChecksum(content);
  String get digest => canonicalChecksum({
    'inputChecksum': inputChecksum,
    'mapping': mapping.indices,
    'report': csvReportJson(report),
  });
}

class CsvImportResult {
  CsvImportResult({
    required String operationId,
    required this.digest,
    required this.inputChecksum,
    required DateTime importedAt,
    required List<String> itemIds,
    required this.totalRows,
    required this.skippedRows,
    required List<int> mapping,
    required this.skipInvalid,
  }) : operationId = boundedText(operationId, 100),
       importedAt = importedAt.toUtc(),
       itemIds = List.unmodifiable(itemIds),
       mapping = List.unmodifiable(mapping) {
    for (final hash in [digest, inputChecksum]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw const LocalDataException('Mã dữ liệu CSV không hợp lệ.');
      }
    }
    boundedInt(totalRows, 1, maxCsvRows);
    boundedInt(skippedRows, 0, maxCsvRows);
    if (itemIds.isEmpty ||
        itemIds.length > maxCsvRows ||
        itemIds.toSet().length != itemIds.length ||
        itemIds.length + skippedRows != totalRows ||
        (!skipInvalid && skippedRows > 0) ||
        mapping.length != 3 ||
        mapping.toSet().length != 3 ||
        mapping.any((n) => n < 0 || n > 11)) {
      throw const LocalDataException('Kết quả nhập CSV không nhất quán.');
    }
    for (final id in itemIds) {
      uuidValue(id);
    }
  }
  final String operationId, digest, inputChecksum;
  final DateTime importedAt;
  final List<String> itemIds;
  final int totalRows, skippedRows;
  final List<int> mapping;
  final bool skipInvalid;
  int get acceptedCount => itemIds.length;
  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'digest': digest,
    'inputChecksum': inputChecksum,
    'importedAt': importedAt.toIso8601String(),
    'itemIds': itemIds,
    'totalRows': totalRows,
    'skippedRows': skippedRows,
    'mapping': mapping,
    'skipInvalid': skipInvalid,
  };
  factory CsvImportResult.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'operationId',
      'digest',
      'inputChecksum',
      'importedAt',
      'itemIds',
      'totalRows',
      'skippedRows',
      'mapping',
      'skipInvalid',
    ]);
    final ids = j['itemIds'], mapping = j['mapping'];
    if (ids is! List || mapping is! List || j['skipInvalid'] is! bool) {
      throw const LocalDataException('Kết quả CSV không đúng định dạng.');
    }
    return CsvImportResult(
      operationId: boundedText(j['operationId'], 100),
      digest: boundedText(j['digest'], 64),
      inputChecksum: boundedText(j['inputChecksum'], 64),
      importedAt: utcValue(j['importedAt']),
      itemIds: ids.map(uuidValue).toList(),
      totalRows: boundedInt(j['totalRows'], 1, maxCsvRows),
      skippedRows: boundedInt(j['skippedRows'], 0, maxCsvRows),
      mapping: mapping.map((n) => boundedInt(n, 0, 11)).toList(),
      skipInvalid: j['skipInvalid'] as bool,
    );
  }
}
