import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/files/canonical_json.dart';
import '../../../core/local/local_database.dart';
import '../../../core/local/local_models.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';
import '../domain/local_csv_import.dart';
import '../domain/vocabulary_import.dart';
import 'admin_content_store.dart';
import 'vocabulary_csv_parser.dart';

/// Preview is read-only. Commit is called inside the Admin LocalCommit boundary.
class AdminCsvStore {
  AdminCsvStore(this.db, this.contentStore, this.clock);
  final LocalDatabase db;
  final AdminContentStore contentStore;
  final DateTime Function() clock;
  static const parser = VocabularyCsvParser(existingLabel: 'học liệu Admin');
  Future<Set<String>> _keys() async {
    final latest = <String, ContentRevision>{};
    for (final record in await contentStore.load()) {
      latest.putIfAbsent(record.itemId, () => record);
    }
    return {
      for (final record in latest.values)
        if (record.payload case final VocabularyContent word)
          vocabularyKey(word.hanzi, word.pinyin),
    };
  }

  Future<CsvImportPreview> preview(
    String content,
    VocabularyColumnMapping mapping,
  ) async {
    final table = parser.parse(content);
    final report = parser.validate(table, mapping, await _keys());
    final revision = await contentStore.meta('revision');
    if (revision == null) {
      throw const LocalDataException('Mở database Admin trước khi nhập CSV.');
    }
    return CsvImportPreview(
      content: content,
      mapping: mapping,
      report: report,
      revision: int.parse(revision),
    );
  }

  Future<void> commit(
    CsvImportPreview prepared,
    bool skipInvalid,
    String operationId,
  ) async {
    if (operationId.trim() != operationId) {
      throw const LocalDataException('Mã thao tác CSV không hợp lệ.');
    }
    final current = await preview(prepared.content, prepared.mapping);
    if (current.digest != prepared.digest) {
      throw const LocalDataException(
        'Học liệu hoặc CSV đã thay đổi. Kiểm tra lại với dữ liệu mới trước khi xác nhận.',
      );
    }
    if (current.report.drafts.isEmpty ||
        (!skipInvalid && current.report.issues.isNotEmpty)) {
      throw const LocalDataException(
        'Chưa có dòng hợp lệ hoặc chưa đồng ý bỏ qua dòng lỗi.',
      );
    }
    final ids = await contentStore.insertCsvDrafts([
      for (final draft in current.report.drafts)
        VocabularyContent(
          hanzi: draft.hanzi,
          pinyin: draft.pinyin,
          vietnamese: draft.vietnamese,
        ),
    ]);
    final result = CsvImportResult(
      operationId: operationId,
      digest: prepared.digest,
      inputChecksum: prepared.inputChecksum,
      importedAt: clock(),
      itemIds: ids,
      totalRows: current.report.drafts.length + current.report.rejectedRecords,
      skippedRows: current.report.rejectedRecords,
      mapping: prepared.mapping.indices,
      skipInvalid: skipInvalid,
    );
    await contentStore.setMeta(
      'csv-import:$operationId',
      canonicalJson(result.toJson()),
    );
  }

  Future<List<CsvImportResult>> results() async {
    final rows = await (db.select(
      db.localMetadata,
    )..where((m) => m.key.like('csv-import:%'))).get();
    final results = [
      for (final row in rows)
        CsvImportResult.fromJson(jsonDecode(row.value) as Map<String, dynamic>),
    ];
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].key != 'csv-import:${results[i].operationId}') {
        throw const LocalDataException('Lịch sử CSV không khớp mã thao tác.');
      }
    }
    results.sort((a, b) => b.importedAt.compareTo(a.importedAt));
    return results;
  }
}
