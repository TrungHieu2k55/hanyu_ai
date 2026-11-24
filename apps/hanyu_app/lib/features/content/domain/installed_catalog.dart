import 'dart:convert';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/json_contract.dart';
import '../../../core/local/local_models.dart';
import '../../admin/domain/content_payload.dart';
import '../../admin/domain/content_revision.dart';
import 'content_package.dart';

class CatalogReceipt {
  CatalogReceipt({
    required String publisherId,
    required String packageId,
    required int version,
    required String checksum,
  }) : publisherId = uuidValue(publisherId),
       packageId = uuidValue(packageId),
       version = boundedInt(version, 1, 0x7fffffff),
       checksum = checksum {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      throw const LocalDataException('Checksum receipt gói không hợp lệ.');
    }
  }
  factory CatalogReceipt.fromPackage(ContentPackage p) => CatalogReceipt(
    publisherId: p.publisherId,
    packageId: p.packageId,
    version: p.version,
    checksum: p.checksum,
  );
  final String publisherId, packageId, checksum;
  final int version;
  String get key => '$publisherId:$packageId:$version';
  Map<String, dynamic> toJson() => {
    'publisherId': publisherId,
    'packageId': packageId,
    'version': version,
    'checksum': checksum,
  };
  factory CatalogReceipt.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, ['publisherId', 'packageId', 'version', 'checksum']);
    return CatalogReceipt(
      publisherId: uuidValue(j['publisherId']),
      packageId: uuidValue(j['packageId']),
      version: boundedInt(j['version'], 1, 0x7fffffff),
      checksum: boundedText(j['checksum'], 64),
    );
  }
}

/// Last known vocabulary definition; personal fields live in local_words/schedules, never here.
class RetainedWordDefinition {
  RetainedWordDefinition({required String publisherId, required this.record})
    : publisherId = uuidValue(publisherId) {
    if (record.kind != ContentKind.vocabulary) {
      throw const LocalDataException('Chỉ giữ định nghĩa từ vựng.');
    }
  }
  final String publisherId;
  final ContentRevision record;
  String get id => 'content:$publisherId:${record.itemId}';
  Map<String, dynamic> toJson() => {
    'publisherId': publisherId,
    'record': record.toJson(),
  };
  factory RetainedWordDefinition.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, ['publisherId', 'record']);
    return RetainedWordDefinition(
      publisherId: uuidValue(j['publisherId']),
      record: ContentRevision.fromJson(jsonObject(j['record'])),
    );
  }
}

/// Immutable catalog boundary, also used by backup preflight before SQL mutation.
class InstalledCatalog {
  InstalledCatalog({
    List<ContentPackage> packages = const [],
    this.activePackageId,
    List<CatalogReceipt> receiptHistory = const [],
    Map<String, RetainedWordDefinition> retainedWords = const {},
  }) : packages = List.unmodifiable(packages),
       receiptHistory = List.unmodifiable(receiptHistory),
       retainedWords = Map.unmodifiable(retainedWords) {
    _validate();
  }
  final List<ContentPackage> packages;
  final String? activePackageId;
  final List<CatalogReceipt> receiptHistory;
  final Map<String, RetainedWordDefinition> retainedWords;
  ContentPackage? get active =>
      packages.where((p) => p.packageId == activePackageId).firstOrNull;
  Set<String> get _managedIds => {
    for (final p in packages)
      for (final r in p.records)
        if (r.kind == ContentKind.vocabulary) p.wordId(r.itemId),
    ...retainedWords.keys,
  };
  int get managedWordCount => _managedIds.length;
  Map<String, dynamic> toJson() => {
    'packages': packages.map((p) => p.toJson()).toList(),
    'activePackageId': activePackageId,
    'receiptHistory': receiptHistory.map((r) => r.toJson()).toList(),
    'retainedWords': retainedWords.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory InstalledCatalog.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'packages',
      'activePackageId',
      'receiptHistory',
      'retainedWords',
    ]);
    if (j['packages'] is! List ||
        (j['packages'] as List).length > 5 ||
        j['receiptHistory'] is! List) {
      throw const LocalDataException('Danh mục gói không hợp lệ.');
    }
    return InstalledCatalog(
      packages: (j['packages'] as List)
          .map((p) => ContentPackage.fromJson(jsonObject(p)))
          .toList(),
      activePackageId: j['activePackageId'] == null
          ? null
          : uuidValue(j['activePackageId']),
      receiptHistory: (j['receiptHistory'] as List)
          .map((r) => CatalogReceipt.fromJson(jsonObject(r)))
          .toList(),
      retainedWords: jsonObject(j['retainedWords']).map(
        (k, v) => MapEntry(k, RetainedWordDefinition.fromJson(jsonObject(v))),
      ),
    );
  }
  void _validate() {
    if (packages.length > 5 ||
        packages.map((p) => p.packageId).toSet().length != packages.length ||
        (activePackageId != null && active == null)) {
      throw const LocalDataException(
        'Tối đa năm gói; gói đang dùng phải được cài.',
      );
    }
    final owners = <String, String>{},
        receipts = <String, CatalogReceipt>{},
        newest = <String, int>{};
    for (final r in receiptHistory) {
      final owner = owners.putIfAbsent(r.packageId, () => r.publisherId);
      if (owner != r.publisherId || receipts.containsKey(r.key)) {
        throw const LocalDataException(
          'Lịch sử gói trùng hoặc khác chủ sở hữu.',
        );
      }
      receipts[r.key] = r;
      if ((newest[r.packageId] ?? 0) < r.version) {
        newest[r.packageId] = r.version;
      }
    }
    final kinds = <String, ContentKind>{};
    for (final p in packages) {
      final receipt = receipts['${p.publisherId}:${p.packageId}:${p.version}'];
      if (receipt?.checksum != p.checksum ||
          newest[p.packageId] != p.version ||
          owners[p.packageId] != p.publisherId) {
        throw const LocalDataException(
          'Gói thiếu receipt, khác checksum hoặc thấp hơn phiên bản đã nhận.',
        );
      }
      for (final r in p.records) {
        final key = p.wordId(r.itemId),
            old = kinds.putIfAbsent(p.wordId(r.itemId), () => r.kind);
        if (old != r.kind) {
          throw LocalDataException(
            'Loại học liệu đã đổi trong namespace $key.',
          );
        }
      }
    }
    for (final e in retainedWords.entries) {
      if (e.key != e.value.id ||
          e.key.length > 100 ||
          (kinds[e.key] != null && kinds[e.key] != ContentKind.vocabulary)) {
        throw const LocalDataException(
          'Định nghĩa giữ lại sai namespace hoặc loại học liệu.',
        );
      }
    }
    if (managedWordCount > 5000) {
      throw const LocalDataException('Danh mục và từ giữ lại vượt 5.000 từ.');
    }
    final payload = {
      'packages': packages.map((p) => p.toJson()).toList(),
      'retainedWords': retainedWords.map((k, v) => MapEntry(k, v.toJson())),
    };
    if (utf8.encode(canonicalJson(payload)).length > 6 * 1024 * 1024) {
      throw const LocalDataException('Danh mục và từ giữ lại vượt 6 MiB.');
    }
  }
}
