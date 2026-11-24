import 'dart:convert';

import 'package:drift/drift.dart';

import '../../features/admin/domain/content_payload.dart';
import '../../features/content/domain/content_package.dart';
import '../../features/content/domain/installed_catalog.dart';
import '../../features/vocabulary/domain/vocabulary_item.dart';
import '../files/canonical_json.dart';
import '../files/local_file_transfer.dart';
import 'local_database.dart';
import 'local_models.dart';

class CatalogInstallPreview {
  const CatalogInstallPreview._(this.package, this.baseRevision, this.previous);

  final ContentPackage package;
  final int baseRevision;
  final ContentPackage? previous;

  Set<String> get added => _ids(package).difference(_ids(previous));
  Set<String> get removed => _ids(previous).difference(_ids(package));
  bool get alreadyInstalled => previous?.checksum == package.checksum;

  static Set<String> _ids(ContentPackage? package) => {
    ...?package?.records.map((record) => record.itemId),
  };
}

/// Mutation methods belong inside the learner repository transaction.
class LearningCatalogStore {
  const LearningCatalogStore(this.db);

  final LocalDatabase db;
  static const _activeKey = 'activePackageId';
  static const _retainedKey = 'retainedCatalogWords';

  Future<InstalledCatalog> load() async {
    final rows = await db.select(db.localInstalledPackages).get();
    final receipts = await db.select(db.localCatalogReceipts).get();
    final metadata = await (db.select(
      db.localMetadata,
    )..where((row) => row.key.isIn([_activeKey, _retainedKey]))).get();
    final values = {for (final row in metadata) row.key: row.value};
    final packages = <ContentPackage>[];
    for (final row in rows) {
      final package = ContentPackage.fromJson(
        jsonDecode(row.dataJson) as Map<String, dynamic>,
      );
      if (package.packageId != row.packageId ||
          package.publisherId != row.publisherId ||
          package.version != row.version ||
          package.checksum != row.checksum) {
        throw const LocalDataException(
          'Gói đã lưu không khớp thông tin phiên bản.',
        );
      }
      packages.add(package);
    }
    final retained =
        jsonDecode(values[_retainedKey] ?? '{}') as Map<String, dynamic>;
    return InstalledCatalog(
      packages: packages,
      activePackageId: values[_activeKey],
      receiptHistory: [
        for (final row in receipts)
          CatalogReceipt(
            publisherId: row.publisherId,
            packageId: row.packageId,
            version: row.version,
            checksum: row.checksum,
          ),
      ],
      retainedWords: retained.map(
        (id, value) => MapEntry(
          id,
          RetainedWordDefinition.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  static Map<String, RetainedWordDefinition> definitions(
    InstalledCatalog catalog,
  ) {
    final result = {...catalog.retainedWords};
    final active = catalog.active;
    final inactive = catalog.packages.where((p) => p != active).toList()
      ..sort((a, b) => a.packageId.compareTo(b.packageId));
    for (final package in [...inactive, ?active]) {
      for (final record in package.records.where(
        (r) => r.kind == ContentKind.vocabulary,
      )) {
        final definition = RetainedWordDefinition(
          publisherId: package.publisherId,
          record: record,
        );
        final old = result[definition.id];
        if (package == active ||
            old == null ||
            old.record.revision <= record.revision) {
          result[definition.id] = definition;
        }
      }
    }
    return result;
  }

  static VocabularyItem word(RetainedWordDefinition definition) {
    final payload = definition.record.payload as VocabularyContent;
    return VocabularyItem(
      id: definition.id,
      level: payload.targetLevel,
      hanzi: payload.hanzi,
      pinyin: payload.pinyin,
      vietnamese: payload.vietnamese,
      exampleHanzi: payload.exampleHanzi,
      exampleVietnamese: payload.exampleVietnamese,
    );
  }

  Future<CatalogInstallPreview> prepare(
    LocalJsonFile file,
    int baseRevision,
  ) async {
    final package = ContentPackage.fromFile(file);
    final catalog = await load();
    await _nextInstall(catalog, package);
    return CatalogInstallPreview._(
      package,
      baseRevision,
      catalog.packages
          .where((p) => p.packageId == package.packageId)
          .firstOrNull,
    );
  }

  Future<void> install(
    CatalogInstallPreview preview, {
    required bool activate,
  }) async {
    final current = await load();
    final next = await _nextInstall(
      current,
      preview.package,
      activate: activate,
    );
    if (identical(current, next)) return;
    await _apply(next);
  }

  Future<InstalledCatalog> _nextInstall(
    InstalledCatalog current,
    ContentPackage package, {
    bool activate = false,
  }) async {
    final history = current.receiptHistory.where(
      (r) => r.packageId == package.packageId,
    );
    for (final receipt in history) {
      if (receipt.publisherId != package.publisherId ||
          receipt.version > package.version ||
          (receipt.version == package.version &&
              receipt.checksum != package.checksum)) {
        throw const LocalDataException(
          'Gói khác nguồn, đã bị thay nội dung hoặc thấp hơn bản từng cài.',
        );
      }
    }
    final installed = current.packages
        .where((p) => p.packageId == package.packageId)
        .firstOrNull;
    if (installed?.checksum == package.checksum && !activate) return current;
    final knownKinds = {
      for (final p in current.packages)
        for (final r in p.records) p.wordId(r.itemId): r.kind,
      for (final id in current.retainedWords.keys) id: ContentKind.vocabulary,
    };
    for (final record in package.records) {
      final kind = knownKinds[package.wordId(record.itemId)];
      if (kind != null && kind != record.kind) {
        throw const LocalDataException(
          'Một mã học liệu đã được dùng cho loại nội dung khác.',
        );
      }
    }
    return _transition(
      current,
      [
        ...current.packages.where((p) => p.packageId != package.packageId),
        package,
      ],
      activate ? package.packageId : current.activePackageId,
      [
        ...current.receiptHistory,
        if (!history.any((r) => r.version == package.version))
          CatalogReceipt.fromPackage(package),
      ],
    );
  }

  Future<void> activate(String? packageId) async {
    final current = await load();
    await _apply(
      await _transition(
        current,
        current.packages,
        packageId,
        current.receiptHistory,
      ),
    );
  }

  Future<void> remove(String packageId) async {
    final current = await load();
    if (!current.packages.any((p) => p.packageId == packageId)) {
      throw const LocalDataException('Không tìm thấy gói đã cài.');
    }
    await _apply(
      await _transition(
        current,
        current.packages.where((p) => p.packageId != packageId).toList(),
        current.activePackageId == packageId ? null : current.activePackageId,
        current.receiptHistory,
      ),
    );
  }

  Future<InstalledCatalog> _transition(
    InstalledCatalog current,
    List<ContentPackage> packages,
    String? activeId,
    List<CatalogReceipt> receipts,
  ) async {
    final installedWords = {
      for (final p in packages)
        for (final r in p.records)
          if (r.kind == ContentKind.vocabulary) p.wordId(r.itemId),
    };
    final words = await db.select(db.localWords).get();
    final activeSchedules = (await (db.select(
      db.localSchedules,
    )..where((r) => r.active.equals(true))).get()).map((r) => r.wordId).toSet();
    final oldDefinitions = definitions(current);
    final retained = <String, RetainedWordDefinition>{};
    for (final row in words) {
      if (!row.id.startsWith('content:')) continue;
      final definition = oldDefinitions[row.id];
      if (row.personal || definition == null) {
        throw const LocalDataException(
          'Mã từ trong gói xung đột với dữ liệu hiện có.',
        );
      }
      if (!installedWords.contains(row.id) &&
          (row.saved ||
              row.note.isNotEmpty ||
              activeSchedules.contains(row.id))) {
        retained[row.id] = definition;
      }
    }
    final next = InstalledCatalog(
      packages: packages,
      activePackageId: activeId,
      receiptHistory: receipts,
      retainedWords: retained,
    );
    if (words.where((row) => !row.id.startsWith('content:')).length +
            next.managedWordCount >
        10000) {
      throw const LocalDataException('Thư viện vượt 10.000 từ.');
    }
    return next;
  }

  Future<void> _apply(InstalledCatalog catalog) async {
    final items = definitions(catalog);
    final existing = await (db.select(
      db.localWords,
    )..where((row) => row.id.like('content:%'))).get();
    await db.batch((batch) {
      for (final row in existing.where((row) => !items.containsKey(row.id))) {
        batch.deleteWhere(db.localWords, (table) => table.id.equals(row.id));
      }
      for (final item in items.values.map(word)) {
        final row = LocalWordsCompanion.insert(
          id: item.id,
          hanzi: item.hanzi,
          pinyin: item.pinyin,
          meaning: item.vietnamese,
          personal: false,
          exampleHanzi: Value(item.exampleHanzi),
          exampleVietnamese: Value(item.exampleVietnamese),
        );
        batch.insert(
          db.localWords,
          row,
          onConflict: DoUpdate(
            (_) => LocalWordsCompanion(
              hanzi: row.hanzi,
              pinyin: row.pinyin,
              meaning: row.meaning,
              exampleHanzi: row.exampleHanzi,
              exampleVietnamese: row.exampleVietnamese,
            ),
          ),
        );
      }
    });
    await writeCatalog(catalog);
  }

  /// Restore writes catalog metadata separately from validated word and review rows.
  Future<void> writeCatalog(InstalledCatalog catalog) async {
    await db.delete(db.localInstalledPackages).go();
    await db.delete(db.localCatalogReceipts).go();
    await (db.delete(
      db.localMetadata,
    )..where((r) => r.key.isIn([_activeKey, _retainedKey]))).go();
    await db.batch((batch) {
      batch.insertAll(db.localInstalledPackages, [
        for (final p in catalog.packages)
          LocalInstalledPackagesCompanion.insert(
            packageId: p.packageId,
            publisherId: p.publisherId,
            version: p.version,
            dataJson: canonicalJson(p.toJson()),
            checksum: p.checksum,
          ),
      ]);
      batch.insertAll(db.localCatalogReceipts, [
        for (final r in catalog.receiptHistory)
          LocalCatalogReceiptsCompanion.insert(
            packageId: r.packageId,
            publisherId: r.publisherId,
            version: r.version,
            checksum: r.checksum,
          ),
      ]);
      if (catalog.activePackageId case final id?) {
        batch.insert(
          db.localMetadata,
          LocalMetadataCompanion.insert(key: _activeKey, value: id),
        );
      }
      if (catalog.retainedWords.isNotEmpty) {
        batch.insert(
          db.localMetadata,
          LocalMetadataCompanion.insert(
            key: _retainedKey,
            value: canonicalJson(
              catalog.retainedWords.map(
                (id, word) => MapEntry(id, word.toJson()),
              ),
            ),
          ),
        );
      }
    });
  }
}
