import 'package:drift/drift.dart';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/json_contract.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_database.dart';
import '../../../core/local/local_models.dart';
import '../../content/domain/content_package.dart';
import '../domain/content_revision.dart';
import 'admin_content_store.dart';

class PackageSelection {
  PackageSelection({required String itemId, required int revision})
    : itemId = uuidValue(itemId),
      revision = boundedInt(revision, 1, 0x7fffffff);
  final String itemId;
  final int revision;
}

class AdminPackagePreview {
  AdminPackagePreview._(this.baseRevision, this.package);
  final int baseRevision;
  final ContentPackage package;
}

/// Called inside the repository transaction; never owns file delivery or learner SQL.
class AdminPackageStore {
  AdminPackageStore(this.db, this.content, this.clock);
  final LocalDatabase db;
  final AdminContentStore content;
  final DateTime Function() clock;
  ContentPackage _decode(LocalAdminPackage row) {
    final p = ContentPackage.fromFile(
      LocalJsonFile.fromBytes(
        row.bytes,
        name: 'package.json',
        kind: LocalJsonKind.contentPackage,
      ),
    );
    if (p.packageId != row.packageId ||
        p.version != row.version ||
        p.checksum != row.checksum) {
      throw const LocalDataException('Snapshot xuất không khớp dữ liệu lưu.');
    }
    return p;
  }

  Future<List<ContentPackage>> load() async => [
    for (final row
        in await (db.select(db.localAdminPackages)..orderBy([
              (r) => OrderingTerm.asc(r.packageId),
              (r) => OrderingTerm.desc(r.version),
            ]))
            .get())
      _decode(row),
  ];
  Future<int> _nextVersion(String id) async {
    final rows =
        await (db.select(db.localAdminPackages)
              ..where((r) => r.packageId.equals(id))
              ..orderBy([(r) => OrderingTerm.desc(r.version)])
              ..limit(1))
            .get();
    return rows.isEmpty
        ? 1
        : boundedInt(rows.single.version + 1, 1, 0x7fffffff);
  }

  Future<List<ContentRevision>> _select(
    List<PackageSelection> selection,
    PackageMode mode,
  ) async {
    if (selection.isEmpty ||
        selection.length > 1064 ||
        selection.map((s) => s.itemId).toSet().length != selection.length) {
      throw const LocalDataException(
        'Chọn từ 1 đến 1.064 học liệu, mỗi mã một phiên bản.',
      );
    }
    final all = await content.load(), chosen = <ContentRevision>[];
    for (final s in selection) {
      final versions = all.where((r) => r.itemId == s.itemId).toList();
      final eligible =
          versions
              .where(
                (r) => mode == PackageMode.reviewed
                    ? r.state == ContentState.published
                    : true,
              )
              .toList()
            ..sort((a, b) => b.revision.compareTo(a.revision));
      if (eligible.isEmpty || eligible.first.revision != s.revision) {
        throw const LocalDataException(
          'Học liệu đã đổi; chọn lại phiên bản mới nhất hoặc bản đang công bố.',
        );
      }
      chosen.add(eligible.first);
    }
    return chosen;
  }

  Future<AdminPackagePreview> prepare({
    required int baseRevision,
    required String packageId,
    required PackageMode mode,
    required List<PackageSelection> selection,
  }) async {
    final id = uuidValue(packageId), identity = await content.identity();
    final selected = await _select(selection, mode);
    final p = ContentPackage.create(
      publisherId: identity.publisherId,
      packageId: id,
      version: await _nextVersion(id),
      mode: mode,
      exportedAt: clock(),
      records: selected,
    );
    return AdminPackagePreview._(baseRevision, p);
  }

  Future<void> commit(AdminPackagePreview preview) async {
    final p = ContentPackage.fromFile(preview.package.toFile());
    if ((await content.identity()).publisherId != p.publisherId ||
        await _nextVersion(p.packageId) != p.version) {
      throw const LocalDataException(
        'Nguồn hoặc phiên bản gói đã đổi; xem trước lại.',
      );
    }
    final records = await _select([
      for (final r in p.records)
        PackageSelection(itemId: r.itemId, revision: r.revision),
    ], p.mode);
    if (canonicalJson(records.map(ContentPackage.recordJson).toList()) !=
        canonicalJson(p.records.map(ContentPackage.recordJson).toList())) {
      throw const LocalDataException('Nội dung đã đổi so với bản xem trước.');
    }
    for (final r in records) {
      await (db.update(db.localAdminRevisions)..where(
            (row) =>
                row.itemId.equals(r.itemId) & row.revision.equals(r.revision),
          ))
          .write(const LocalAdminRevisionsCompanion(exported: Value(true)));
    }
    await db
        .into(db.localAdminPackages)
        .insert(
          LocalAdminPackagesCompanion.insert(
            packageId: p.packageId,
            version: p.version,
            bytes: p.toFile().bytes,
            checksum: p.checksum,
          ),
        );
  }

  Future<LocalJsonFile> file(String packageId, int version) async {
    uuidValue(packageId);
    boundedInt(version, 1, 0x7fffffff);
    final row =
        await (db.select(db.localAdminPackages)..where(
              (r) => r.packageId.equals(packageId) & r.version.equals(version),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw const LocalDataException('Không tìm thấy phiên bản gói đã lưu.');
    }
    final p = _decode(row);
    // Return stored bytes, not a reconstructed document: re-export is byte-identical.
    return LocalJsonFile.fromBytes(
      row.bytes,
      name: p.toFile().name,
      kind: LocalJsonKind.contentPackage,
    );
  }
}
