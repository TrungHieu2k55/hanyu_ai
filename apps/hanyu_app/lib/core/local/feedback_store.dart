import 'dart:convert';

import 'package:drift/drift.dart';

import '../files/canonical_json.dart';
import '../files/local_file_transfer.dart';
import '../../features/support/domain/local_feedback.dart';
import 'local_database.dart';
import 'local_models.dart';

/// All mutations run inside the repository's LocalCommit transaction.
class FeedbackStore {
  FeedbackStore(this.db, this.clock);
  final LocalDatabase db;
  final DateTime Function() clock;
  Future<List<FeedbackReport>> load() async => List.unmodifiable(
    (await (db.select(db.localFeedbackReports)..orderBy([
              (r) => OrderingTerm.desc(r.updatedAt),
              (r) => OrderingTerm.desc(r.revision),
            ]))
            .get())
        .map(
          (r) => FeedbackReport.fromJson(
            jsonDecode(r.dataJson) as Map<String, dynamic>,
          ),
        ),
  );
  Future<FeedbackReport> read(String id, int revision) async {
    final row =
        await (db.select(db.localFeedbackReports)
              ..where((r) => r.id.equals(id) & r.revision.equals(revision)))
            .getSingleOrNull();
    if (row == null) {
      throw const LocalDataException('Không tìm thấy phiên bản báo lỗi.');
    }
    return FeedbackReport.fromJson(
      jsonDecode(row.dataJson) as Map<String, dynamic>,
    );
  }

  Future<FeedbackReport?> latest(String id) async {
    final row =
        await (db.select(db.localFeedbackReports)
              ..where((r) => r.id.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.revision)])
              ..limit(1))
            .getSingleOrNull();
    return row == null
        ? null
        : FeedbackReport.fromJson(
            jsonDecode(row.dataJson) as Map<String, dynamic>,
          );
  }

  String _pin(String id, int revision) => 'feedback-export:$id:$revision';
  Future<String?> _pinned(String id, int revision) async => (await (db.select(
    db.localMetadata,
  )..where((m) => m.key.equals(_pin(id, revision)))).getSingleOrNull())?.value;

  Future<void> save({
    required String id,
    required int reportRevision,
    required String body,
    FeedbackContext? context,
    bool draft = false,
  }) async {
    final old = await latest(id);
    if ((old == null && reportRevision != 0) ||
        (old != null && old.revision != reportRevision)) {
      throw const LocalConflict();
    }
    final immutable =
        old != null &&
        (old.state == FeedbackState.exported ||
            old.state == FeedbackState.resolvedImported ||
            await _pinned(id, old.revision) != null);
    final same =
        old != null &&
        old.body == body.trim() &&
        canonicalJson(old.context?.values) == canonicalJson(context?.values);
    if (immutable && same) return;
    final report = FeedbackReport.create(
      id: id,
      revision: old == null
          ? 1
          : immutable
          ? old.revision + 1
          : old.revision,
      body: body,
      context: context,
      createdAt: old?.createdAt ?? clock(),
      updatedAt: old != null && clock().isBefore(old.updatedAt)
          ? old.updatedAt
          : clock(),
      state: draft ? FeedbackState.draft : FeedbackState.recorded,
    );
    if (old == null || immutable) {
      final count = await db
          .customSelect('SELECT COUNT(*) AS n FROM local_feedback_reports')
          .getSingle();
      if (count.read<int>('n') >= 1000) {
        throw const LocalDataException(
          'Đã đạt giới hạn 1.000 phiên bản báo lỗi trên thiết bị.',
        );
      }
    }
    await _put(report);
  }

  Future<void> _put(FeedbackReport report) => db
      .into(db.localFeedbackReports)
      .insertOnConflictUpdate(
        LocalFeedbackReportsCompanion.insert(
          id: report.id,
          revision: report.revision,
          dataJson: canonicalJson(report.toJson()),
          state: report.state.name,
          updatedAt: report.updatedAt,
        ),
      );

  Future<Map<String, String>> exportPins() async => {
    for (final row in await (db.select(
      db.localMetadata,
    )..where((r) => r.key.like('feedback-export:%'))).get())
      row.key: row.value,
  };

  Future<void> replaceFromBackup(
    List<FeedbackReport> reports,
    Map<String, String> pins,
  ) async {
    await db.delete(db.localFeedbackReports).go();
    await (db.delete(
      db.localMetadata,
    )..where((r) => r.key.like('feedback-export:%'))).go();
    for (final report in reports) {
      await _put(report);
    }
    await db.batch(
      (batch) => batch.insertAll(db.localMetadata, [
        for (final pin in pins.entries)
          LocalMetadataCompanion.insert(key: pin.key, value: pin.value),
      ]),
    );
  }

  Future<void> prepareExport(String id, int revision) async {
    final report = await read(id, revision);
    report.toFile(); // Drafts cannot be frozen/exported.
    final pin = await _pinned(id, revision);
    if (pin != null && pin != report.checksum) {
      throw const LocalDataException('Phiên bản xuất không còn nguyên vẹn.');
    }
    await db
        .into(db.localMetadata)
        .insertOnConflictUpdate(
          LocalMetadataCompanion.insert(
            key: _pin(id, revision),
            value: report.checksum,
          ),
        );
  }

  Future<LocalJsonFile> exportFile(String id, int revision) async {
    final report = await read(id, revision);
    if (await _pinned(id, revision) != report.checksum) {
      throw const LocalDataException(
        'Chuẩn bị phiên bản báo lỗi trước khi xuất.',
      );
    }
    return report.toFile();
  }

  Future<void> markExported(String id, int revision, String checksum) async {
    final report = await read(id, revision);
    if (report.checksum != checksum ||
        await _pinned(id, revision) != checksum) {
      throw const LocalDataException(
        'File đã xuất không khớp phiên bản được khóa.',
      );
    }
    if (report.state == FeedbackState.resolvedImported) return;
    await _put(report.withState(FeedbackState.exported));
  }

  Future<void> validateReceipt(FeedbackReceipt receipt) async {
    final report = await latest(receipt.reportId);
    if (report == null ||
        report.state == FeedbackState.draft ||
        !receipt.matches(report.id, report.revision, report.checksum)) {
      throw const LocalDataException(
        'Kết quả không khớp phiên bản báo lỗi mới nhất trên thiết bị.',
      );
    }
    if (report.outcome != null &&
        canonicalJson(report.outcome!.toJson()) !=
            canonicalJson(receipt.toJson())) {
      throw const LocalDataException(
        'Phiên bản này đã có kết quả khác; không ghi đè lịch sử.',
      );
    }
  }

  Future<void> importReceipt(FeedbackReceipt receipt) async {
    await validateReceipt(receipt);
    final report = await read(receipt.reportId, receipt.reportRevision);
    await _put(
      report.withState(FeedbackState.resolvedImported, outcome: receipt),
    );
  }
}
