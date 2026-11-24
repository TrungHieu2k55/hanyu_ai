import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/local/local_database.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/data/admin_package_store.dart';
import 'package:doanchuyennganh2/features/admin/data/local_admin_repository.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_revision.dart';
import 'package:doanchuyennganh2/features/content/domain/content_package.dart';

const item = '00000000-0000-4000-8000-000000000100',
    package = '00000000-0000-4000-8000-000000000002';
final now = DateTime.utc(2026, 11, 22);
VocabularyContent word([String meaning = 'bạn']) =>
    VocabularyContent(hanzi: '朋友', pinyin: 'péngyou', vietnamese: meaning);
void main() {
  late LocalAdminRepository repo;
  setUp(
    () => repo = LocalAdminRepository(
      LocalDatabase(NativeDatabase.memory()),
      clock: () => now,
    ),
  );
  tearDown(() => repo.close());
  Future<void> seed() async {
    final s = await repo.loadSnapshot();
    await repo.saveRevision(
      id: item,
      baseRevision: 0,
      payload: word(),
      source: 'Nhóm tự soạn',
      license: 'Cho phép dùng',
      revision: s.revision,
      operationId: 'create',
    );
  }

  Future<AdminPackagePreview> prepare({
    PackageMode mode = PackageMode.trial,
    int number = 1,
  }) => repo.preparePackage(
    packageId: package,
    mode: mode,
    selection: [PackageSelection(itemId: item, revision: number)],
  );
  test('prepare is read-only; trial requires explicit acknowledgement and pins atomically', () async {
    await seed();
    final before = await repo.loadSnapshot();
    final preview = await prepare();
    expect((await repo.loadSnapshot()).revision, before.revision);
    expect((await repo.loadSnapshot()).packages, isEmpty);
    await expectLater(
      repo.commitPackage(preview, operationId: 'export'),
      throwsA(isA<LocalDataException>()),
    );
    var s = await repo.commitPackage(
      preview,
      acceptTrial: true,
      operationId: 'export',
    );
    expect(s.packages.single.version, 1);
    expect(s.content.single.exported, isTrue);
    final bytes = (await repo.exportPackage(package, 1)).bytes;
    s = await repo.commitPackage(
      preview,
      acceptTrial: true,
      operationId: 'export',
    );
    expect(s.packages, hasLength(1));
    expect((await repo.exportPackage(package, 1)).bytes, bytes);
    await expectLater(
      repo.deleteUnexportedDraft(item, 1, revision: s.revision, operationId: 'delete'),
      throwsA(isA<LocalDataException>()),
    );
    final backup = await repo.exportBackup();
    final restored = await repo.restoreBackup(
      repo.prepareBackupRestore(backup),
      revision: s.revision,
      operationId: 'restore',
    );
    expect(restored.packages.single.checksum, preview.package.checksum);
    expect((await repo.exportPackage(package, 1)).bytes, bytes);
  });
  test('CAS rejects stale preview; same operation cannot create next version with changed input', () async {
    await seed();
    final preview = await prepare();
    var s = await repo.loadSnapshot();
    s = await repo.saveIdentityLabel(
      'Tên khác',
      revision: s.revision,
      operationId: 'rename',
    );
    await expectLater(
      repo.commitPackage(preview, acceptTrial: true, operationId: 'stale'),
      throwsA(isA<LocalDataException>()),
    );
    final current = await prepare();
    s = await repo.commitPackage(
      current,
      acceptTrial: true,
      operationId: 'same',
    );
    final next = await prepare();
    expect(next.package.version, 2);
    await expectLater(
      repo.commitPackage(next, acceptTrial: true, operationId: 'same'),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.loadSnapshot()).packages, hasLength(1));
    s = await repo.commitPackage(next, acceptTrial: true, operationId: 'next');
    expect(s.packages.map((p) => p.version), containsAll([1, 2]));
  });
  test('reviewed selects current published; later edits and withdrawal never rewrite frozen bytes', () async {
    await seed();
    await expectLater(
      prepare(mode: PackageMode.reviewed),
      throwsA(isA<LocalDataException>()),
    );
    var s = await repo.loadSnapshot();
    s = await repo.recordReview(
      item,
      1,
      reviewerName: 'Khai báo local',
      note: 'Đối chiếu nguồn',
      revision: s.revision,
      operationId: 'review',
    );
    s = await repo.publishRevision(
      item,
      1,
      revision: s.revision,
      operationId: 'publish',
    );
    final preview = await prepare(mode: PackageMode.reviewed);
    s = await repo.commitPackage(preview, operationId: 'export-reviewed');
    final bytes = (await repo.exportPackage(package, 1)).bytes;
    s = await repo.saveRevision(
      id: item,
      baseRevision: 1,
      payload: word('bạn bè'),
      source: 'Nhóm tự soạn',
      license: 'Cho phép dùng',
      revision: s.revision,
      operationId: 'edit',
    );
    expect(
      (await prepare(mode: PackageMode.reviewed))
          .package
          .records
          .single
          .revision,
      1,
    );
    await expectLater(prepare(), throwsA(isA<LocalDataException>()));
    expect(
      (await prepare(number: 2)).package.records.single.state,
      ContentState.draft,
    );
    s = await repo.withdrawRevision(
      item,
      1,
      revision: s.revision,
      operationId: 'withdraw',
    );
    await expectLater(
      prepare(mode: PackageMode.reviewed),
      throwsA(isA<LocalDataException>()),
    );
    expect((await repo.exportPackage(package, 1)).bytes, bytes);
    expect(
      repo.prepareBackupRestore(await repo.exportBackup()).exports,
      hasLength(1),
    );
  });
  test('SQL failure rolls back export pin, version and receipt; retry same preview succeeds', () async {
    await seed();
    final preview = await prepare();
    await repo.db.customStatement(
      "CREATE TRIGGER fail_package BEFORE INSERT ON local_admin_packages BEGIN SELECT RAISE(ABORT, 'injected'); END",
    );
    await expectLater(
      repo.commitPackage(preview, acceptTrial: true, operationId: 'fault'),
      throwsA(anything),
    );
    final s = await repo.loadSnapshot();
    expect(s.packages, isEmpty);
    expect(s.content.single.exported, isFalse);
    expect(s.revision, preview.baseRevision);
    expect(
      await repo.db
          .customSelect(
            "SELECT * FROM local_receipts WHERE operation_id='fault'",
          )
          .get(),
      isEmpty,
    );
    await repo.db.customStatement('DROP TRIGGER fail_package');
    expect(
      (await repo.commitPackage(
        preview,
        acceptTrial: true,
        operationId: 'fault',
      )).packages.single.version,
      1,
    );
  });
  test('package bytes survive close/reopen of a real SQLite file', () async {
    final dir = await Directory.systemTemp.createTemp('hanyu-export-');
    final file = File('${dir.path}/admin.sqlite');
    await repo.close();
    repo = LocalAdminRepository(
      LocalDatabase(NativeDatabase(file)),
      clock: () => now,
    );
    await seed();
    final preview = await prepare();
    await repo.commitPackage(
      preview,
      acceptTrial: true,
      operationId: 'durable',
    );
    final bytes = (await repo.exportPackage(package, 1)).bytes;
    await repo.close();
    repo = LocalAdminRepository(
      LocalDatabase(NativeDatabase(file)),
      clock: () => now.add(const Duration(days: 2)),
    );
    expect((await repo.loadSnapshot()).packages.single.exportedAt, now);
    expect((await repo.exportPackage(package, 1)).bytes, bytes);
    addTearDown(() async {
      await repo.close();
      await dir.delete(recursive: true);
    });
  });
}
