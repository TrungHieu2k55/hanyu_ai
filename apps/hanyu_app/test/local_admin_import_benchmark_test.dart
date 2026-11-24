import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/vocabulary_import.dart';

void main() {
  test('measure warm file-backed Native CSV preview+commit for 1000 rows', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-csv-benchmark-');
    addTearDown(() => dir.delete(recursive: true));
    final repo = LocalAdminRepository(
      LocalDatabase(NativeDatabase(File('${dir.path}/admin.sqlite'))),
    );
    addTearDown(repo.close);
    await repo.loadSnapshot();
    final csv =
        'h,p,v\n${List.generate(1000, (i) => '字$i,zì $i,nghĩa $i').join('\n')}';
    final watch = Stopwatch()..start();
    final preview = await repo.previewCsv(
      csv,
      const VocabularyColumnMapping(hanzi: 0, pinyin: 1, vietnamese: 2),
    );
    final result = await repo.commitCsv(
      preview,
      skipInvalid: false,
      operationId: 'benchmark-1000',
    );
    watch.stop();
    expect(result.content, hasLength(1000));
    expect(result.imports.single.acceptedCount, 1000);
    stdout.writeln(
      'CSV_BENCHMARK ${jsonEncode({'rows': 1000, 'utf8_bytes': utf8.encode(csv).length, 'preview_commit_ms': watch.elapsedMilliseconds, 'executor': 'NativeDatabase file-backed, after loadSnapshot', 'meets_5s_on_this_run': watch.elapsedMilliseconds < 5000})}',
    );
  }, skip: !const bool.fromEnvironment('CSV_BENCHMARK'));
}
