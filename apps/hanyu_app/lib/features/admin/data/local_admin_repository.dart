import '../../content/domain/content_package.dart';
import 'admin_package_store.dart';

import '../domain/local_csv_import.dart';
import '../domain/vocabulary_import.dart';
import 'admin_csv_store.dart';
import 'admin_backup.dart';
import '../domain/content_payload.dart';
import 'admin_content_store.dart';

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_commit.dart';
import '../../../core/local/local_database.dart';
import '../../../core/local/local_models.dart';
import '../../support/domain/local_feedback.dart';
import '../domain/local_admin.dart';

class LocalAdminRepository {
  LocalAdminRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final LocalDatabase db;
  final DateTime Function() clock;
  late final contentStore = AdminContentStore(db, clock);
  late final csvStore = AdminCsvStore(db, contentStore, clock);
  late final packageStore = AdminPackageStore(db, contentStore, clock);

  Future<LocalAdminSnapshot> loadSnapshot() => db.transaction(() async {
    await db
        .into(db.localMetadata)
        .insert(
          LocalMetadataCompanion.insert(key: 'revision', value: '0'),
          mode: InsertMode.insertOrIgnore,
        );
    await contentStore.initialize();
    return _snapshot();
  });
  Future<LocalAdminSnapshot> _snapshot() async {
    final revision = await (db.select(
      db.localMetadata,
    )..where((r) => r.key.equals('revision'))).getSingle();
    final rows =
        await (db.select(db.localAdminInbox)..orderBy([
              (r) => OrderingTerm.desc(r.receivedAt),
              (r) => OrderingTerm.desc(r.revision),
            ]))
            .get();
    return LocalAdminSnapshot(
      revision: int.parse(revision.value),
      identity: await contentStore.identity(),
      content: await contentStore.load(),
      imports: await csvStore.results(),
      packages: await packageStore.load(),
      inbox: rows.map(_entry).toList(),
    );
  }

  AdminInbox _entry(LocalAdminInboxData row) => AdminInbox(
    report: FeedbackReport.fromJson(
      jsonDecode(row.reportJson) as Map<String, dynamic>,
    ),
    status: InboxStatus.values.byName(row.status),
    receivedAt: row.receivedAt,
    receipt: row.receiptJson == null
        ? null
        : FeedbackReceipt.fromJson(
            jsonDecode(row.receiptJson!) as Map<String, dynamic>,
          ),
  );
  Future<LocalAdminInboxData?> _row(String id, int reportRevision) =>
      (db.select(db.localAdminInbox)..where(
            (r) => r.reportId.equals(id) & r.revision.equals(reportRevision),
          ))
          .getSingleOrNull();

  Future<LocalAdminSnapshot> _commit(
    int revision,
    String operationId,
    Object payload,
    Future<void> Function() action,
  ) => LocalCommit(db).run(
    revision: revision,
    operationId: operationId,
    payload: payload,
    action: action,
    snapshot: () async {
      await _checkCapacity();
      return _snapshot();
    },
  );

  Future<void> _checkCapacity() async {
    // Prospective export payload bound, including existing/future E stores.
    final data = <String, Object?>{};
    for (final table in [
      'local_admin_inbox',
      'local_admin_revisions',
      'local_admin_packages',
      'local_metadata',
      'local_receipts',
    ]) {
      final rows = await db.customSelect('SELECT * FROM $table').get();
      data[table] = [
        for (final row in rows)
          {
            for (final entry in row.data.entries)
              entry.key: entry.value is Uint8List
                  ? base64Encode(entry.value as Uint8List)
                  : entry.value,
          },
      ];
    }
    if (utf8.encode(jsonEncode(data)).length > 8 * 1024 * 1024) {
      throw const LocalDataException(
        'Dữ liệu Admin vượt giới hạn 8 MiB; thao tác chưa được lưu.',
      );
    }
  }

  Future<LocalAdminSnapshot> importFeedback(
    FeedbackReport input, {
    required int revision,
    required String operationId,
  }) {
    // Round-trip through the external contract even for non-UI callers.
    final report = FeedbackReport.fromFile(input.toFile());
    return _commit(
      revision,
      operationId,
      ['inbox-import', report.toTransferJson()],
      () async {
        final old = await _row(report.id, report.revision);
        if (old != null) {
          if (_entry(old).report.checksum != report.checksum) {
            throw const LocalDataException(
              'Cùng mã/phiên bản nhưng nội dung khác; không ghi đè.',
            );
          }
          return;
        }
        final count = await db
            .customSelect('SELECT COUNT(*) AS n FROM local_admin_inbox')
            .getSingle();
        if (count.read<int>('n') >= 1000) {
          throw const LocalDataException(
            'Inbox đã đạt giới hạn 1.000 phiên bản báo lỗi.',
          );
        }
        await db
            .into(db.localAdminInbox)
            .insert(
              LocalAdminInboxCompanion.insert(
                reportId: report.id,
                revision: report.revision,
                reportJson: canonicalJson(report.toJson()),
                status: InboxStatus.open.name,
                receivedAt: clock().toUtc(),
              ),
            );
      },
    );
  }

  Future<LocalAdminSnapshot> updateInbox(
    String id,
    int reportRevision,
    InboxStatus status, {
    String resolution = '',
    String actorLabel = '',
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    ['inbox-update', id, reportRevision, status.name, resolution, actorLabel],
    () async {
      final row = await _row(id, reportRevision);
      if (row == null) {
        throw const LocalDataException('Không tìm thấy báo lỗi trong inbox.');
      }
      final old = _entry(row);
      if (old.status == InboxStatus.closed) {
        if (status == InboxStatus.closed &&
            old.receipt!.resolution == resolution.trim() &&
            old.receipt!.actorLabel == actorLabel.trim()) {
          return;
        }
        throw const LocalDataException(
          'Báo lỗi đã đóng; không ghi đè kết quả đã lưu.',
        );
      }
      final receipt = status == InboxStatus.closed
          ? FeedbackReceipt(
              reportId: id,
              reportRevision: reportRevision,
              reportChecksum: old.report.checksum,
              resolution: resolution,
              actorLabel: actorLabel,
              closedAt: clock(),
            )
          : null;
      await (db.update(db.localAdminInbox)..where(
            (r) => r.reportId.equals(id) & r.revision.equals(reportRevision),
          ))
          .write(
            LocalAdminInboxCompanion(
              status: Value(status.name),
              receiptJson: Value(
                receipt == null ? null : canonicalJson(receipt.toJson()),
              ),
            ),
          );
    },
  );
  Future<LocalJsonFile> exportFeedbackReceipt(String id, int reportRevision) =>
      db.transaction(() async {
        final row = await _row(id, reportRevision);
        if (row == null || _entry(row).receipt == null) {
          throw const LocalDataException(
            'Đóng báo lỗi và lưu kết quả trước khi xuất.',
          );
        }
        return _entry(row).receipt!.toFile();
      });
  Future<LocalAdminSnapshot> saveIdentityLabel(
    String label, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'identity-label',
    label,
  ], () => contentStore.saveLabel(label));
  Future<LocalAdminSnapshot> saveRevision({
    required String id,
    required int baseRevision,
    required ContentPayload payload,
    String source = '',
    String license = '',
    required int revision,
    required String operationId,
  }) => _commit(
    revision,
    operationId,
    [
      'content-save',
      id,
      baseRevision,
      payload.kind.name,
      payload.toJson(),
      source,
      license,
    ],
    () => contentStore.save(
      id: id,
      baseRevision: baseRevision,
      payload: payload,
      source: source,
      license: license,
    ),
  );
  Future<LocalAdminSnapshot> recordReview(
    String id,
    int contentRevision, {
    required String reviewerName,
    required String note,
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'content-review',
    id,
    contentRevision,
    reviewerName,
    note,
  ], () => contentStore.review(id, contentRevision, reviewerName, note));
  Future<LocalAdminSnapshot> publishRevision(
    String id,
    int contentRevision, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'content-publish',
    id,
    contentRevision,
  ], () => contentStore.publish(id, contentRevision));
  Future<LocalAdminSnapshot> withdrawRevision(
    String id,
    int contentRevision, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'content-withdraw',
    id,
    contentRevision,
  ], () => contentStore.withdraw(id, contentRevision));
  Future<LocalAdminSnapshot> deleteUnexportedDraft(
    String id,
    int contentRevision, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'content-delete',
    id,
    contentRevision,
  ], () => contentStore.delete(id, contentRevision));
  Future<LocalAdminSnapshot> seedSamples({
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, [
    'content-samples-v1',
  ], contentStore.samples);
  Future<CsvImportPreview> previewCsv(
    String content,
    VocabularyColumnMapping mapping,
  ) => db.transaction(() => csvStore.preview(content, mapping));
  Future<LocalAdminSnapshot> commitCsv(
    CsvImportPreview preview, {
    required bool skipInvalid,
    required String operationId,
  }) => _commit(preview.revision, operationId, [
    'csv-import',
    preview.digest,
    skipInvalid,
  ], () => csvStore.commit(preview, skipInvalid, operationId));
  Future<AdminPackagePreview> preparePackage({
    required String packageId,
    required PackageMode mode,
    required List<PackageSelection> selection,
  }) => db.transaction(() async {
    final snapshot = await _snapshot();
    return packageStore.prepare(
      baseRevision: snapshot.revision,
      packageId: packageId,
      mode: mode,
      selection: selection,
    );
  });
  Future<LocalAdminSnapshot> commitPackage(
    AdminPackagePreview preview, {
    bool acceptTrial = false,
    required String operationId,
  }) {
    if (preview.package.mode == PackageMode.trial && !acceptTrial) {
      return Future.error(
        const LocalDataException(
          'Xác nhận gói dùng thử có thể chứa nội dung chưa duyệt.',
        ),
      );
    }
    return _commit(preview.baseRevision, operationId, [
      'package-freeze',
      preview.package.toJson(),
    ], () => packageStore.commit(preview));
  }

  Future<LocalJsonFile> exportPackage(String packageId, int version) =>
      db.transaction(() => packageStore.file(packageId, version));
  Future<LocalJsonFile> exportBackup() => db.transaction(() async {
    final snapshot = await _snapshot();
    final metadata = await db.select(db.localMetadata).get();
    final receipts = await db.select(db.localReceipts).get();
    final exports = await db.select(db.localAdminPackages).get();
    return AdminBackup.create(
      identity: snapshot.identity,
      content: snapshot.content,
      inbox: snapshot.inbox,
      metadata: {
        for (final m in metadata)
          if (m.key != 'adminIdentity' && m.key != 'revision') m.key: m.value,
      },
      receipts: receipts
          .map(
            (v) => AdminOperationReceipt(
              operationId: v.operationId,
              fingerprint: v.fingerprint,
            ),
          )
          .toList(),
      exports: exports
          .map(
            (v) => AdminExportSnapshot(
              packageId: v.packageId,
              version: v.version,
              checksum: v.checksum,
              bytes: v.bytes,
            ),
          )
          .toList(),
    ).toFile();
  });
  AdminBackup prepareBackupRestore(LocalJsonFile file) =>
      AdminBackup.fromFile(file);
  Future<LocalAdminSnapshot> restoreBackup(
    AdminBackup backup, {
    required int revision,
    required String operationId,
  }) => _commit(revision, operationId, ['admin-restore', backup.checksum], () async {
    // Revalidate even a programmatically constructed preview before any delete.
    final prepared = AdminBackup.fromFile(backup.toFile());
    if (prepared.receipts.any((r) => r.operationId == operationId)) {
      throw const LocalDataException(
        'Mã khôi phục trùng receipt trong backup; mở lại thao tác khôi phục.',
      );
    }
    await db.delete(db.localAdminRevisions).go();
    await db.delete(db.localAdminInbox).go();
    await db.delete(db.localAdminPackages).go();
    await db.delete(db.localMetadata).go();
    await db.delete(db.localReceipts).go();
    await contentStore.setMeta(
      'adminIdentity',
      canonicalJson(prepared.identity.toJson()),
    );
    for (final entry in prepared.metadata.entries) {
      await contentStore.setMeta(entry.key, entry.value);
    }
    for (final record in prepared.content) {
      await db
          .into(db.localAdminRevisions)
          .insert(
            LocalAdminRevisionsCompanion.insert(
              itemId: record.itemId,
              revision: record.revision,
              kind: record.kind.name,
              dataJson: canonicalJson(record.toJson()),
              state: record.state.name,
              exported: Value(record.exported),
            ),
          );
    }
    for (final item in prepared.inbox) {
      await db
          .into(db.localAdminInbox)
          .insert(
            LocalAdminInboxCompanion.insert(
              reportId: item.report.id,
              revision: item.report.revision,
              reportJson: canonicalJson(item.report.toJson()),
              status: item.status.name,
              receivedAt: item.receivedAt,
              receiptJson: Value(
                item.receipt == null
                    ? null
                    : canonicalJson(item.receipt!.toJson()),
              ),
            ),
          );
    }
    for (final item in prepared.exports) {
      await db
          .into(db.localAdminPackages)
          .insert(
            LocalAdminPackagesCompanion.insert(
              packageId: item.packageId,
              version: item.version,
              bytes: item.bytes,
              checksum: item.checksum,
            ),
          );
    }
    for (final receipt in prepared.receipts) {
      await db
          .into(db.localReceipts)
          .insert(
            LocalReceiptsCompanion.insert(
              operationId: receipt.operationId,
              fingerprint: receipt.fingerprint,
            ),
          );
    }
  });
  Future<void> close() => db.close();
}
