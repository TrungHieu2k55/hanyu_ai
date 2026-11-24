import 'dart:convert';

import 'local_database.dart';
import 'local_models.dart';

/// Shared atomic commit boundary. Each database owns its revision and receipts.
/// A duplicate intent reads current state; it never repeats the mutation.
class LocalCommit {
  const LocalCommit(this.db);
  final LocalDatabase db;

  Future<T> run<T>({
    required int revision,
    required String operationId,
    required Object payload,
    required Future<void> Function() action,
    required Future<T> Function() snapshot,
  }) => db.transaction(() async {
    if (operationId.isEmpty || operationId.length > 100) {
      throw const LocalDataException('Mã thao tác không hợp lệ.');
    }
    final fingerprint = jsonEncode(payload);
    final receipt = await (db.select(
      db.localReceipts,
    )..where((r) => r.operationId.equals(operationId))).getSingleOrNull();
    if (receipt != null) {
      if (receipt.fingerprint != fingerprint) {
        throw const LocalDataException(
          'Mã thao tác đã dùng cho nội dung khác.',
        );
      }
      return snapshot();
    }
    final current = await (db.select(
      db.localMetadata,
    )..where((m) => m.key.equals('revision'))).getSingleOrNull();
    if (current == null || int.tryParse(current.value) != revision) {
      throw const LocalConflict();
    }
    await action();
    await db
        .into(db.localMetadata)
        .insertOnConflictUpdate(
          LocalMetadataCompanion.insert(
            key: 'revision',
            value: '${revision + 1}',
          ),
        );
    await db
        .into(db.localReceipts)
        .insert(
          LocalReceiptsCompanion.insert(
            operationId: operationId,
            fingerprint: fingerprint,
          ),
        );
    // Snapshot failure must also roll back action, revision and receipt.
    return snapshot();
  });
}
