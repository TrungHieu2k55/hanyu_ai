import '../../content/domain/content_package.dart';
import '../domain/local_csv_import.dart';

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/json_contract.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';
import '../../support/domain/local_feedback.dart';
import '../domain/content_payload.dart';
import '../domain/content_revision.dart';
import '../domain/local_admin.dart';

class AdminOperationReceipt {
  AdminOperationReceipt({
    required String operationId,
    required this.fingerprint,
  }) : operationId = boundedText(operationId, 100) {
    try {
      jsonDecode(fingerprint);
    } on FormatException {
      throw const LocalDataException('Receipt thao tác không hợp lệ.');
    }
  }
  final String operationId, fingerprint;
  Map<String, dynamic> toJson() => {
    'operationId': operationId,
    'fingerprint': fingerprint,
  };
  factory AdminOperationReceipt.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, ['operationId', 'fingerprint']);
    return AdminOperationReceipt(
      operationId: boundedText(j['operationId'], 100),
      fingerprint: boundedText(j['fingerprint'], 10 * 1024 * 1024),
    );
  }
}

/// Internal immutable export bytes are carried by backup, never reconstructed.
class AdminExportSnapshot {
  AdminExportSnapshot({
    required String packageId,
    required this.version,
    required this.checksum,
    required Uint8List bytes,
  }) : packageId = uuidValue(packageId),
       bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    boundedInt(version, 1, 0x7fffffff);
    if (bytes.length > 2 * 1024 * 1024 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(checksum)) {
      throw const LocalDataException(
        'Export snapshot quá lớn hoặc checksum sai.',
      );
    }
  }
  final String packageId, checksum;
  final int version;
  final Uint8List bytes;
  Map<String, dynamic> toJson() => {
    'packageId': packageId,
    'version': version,
    'checksum': checksum,
    'bytes': base64Encode(bytes),
  };
  factory AdminExportSnapshot.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, ['packageId', 'version', 'checksum', 'bytes']);
    Uint8List bytes;
    try {
      bytes = base64Decode(boundedText(j['bytes'], 3 * 1024 * 1024));
    } on FormatException {
      throw const LocalDataException(
        'Export snapshot không phải base64 hợp lệ.',
      );
    }
    return AdminExportSnapshot(
      packageId: uuidValue(j['packageId']),
      version: boundedInt(j['version'], 1, 0x7fffffff),
      checksum: boundedText(j['checksum'], 64),
      bytes: bytes,
    );
  }
  Set<String> validate(
    AdminIdentity identity,
    Map<String, ContentRevision> records,
  ) {
    final p = ContentPackage.fromFile(
      LocalJsonFile.fromBytes(
        bytes,
        name: 'snapshot.json',
        kind: LocalJsonKind.contentPackage,
      ),
    );
    if (p.publisherId != identity.publisherId ||
        p.packageId != packageId ||
        p.version != version ||
        p.checksum != checksum) {
      throw const LocalDataException(
        'Export snapshot không khớp danh tính/gói/checksum.',
      );
    }
    final references = <String>{};
    for (final item in p.records) {
      final key = '${item.itemId}:${item.revision}', stored = records[key];
      if (stored == null ||
          !stored.exported ||
          stored.kind != item.kind ||
          canonicalJson(stored.payload.toJson()) !=
              canonicalJson(item.payload.toJson()) ||
          stored.source != item.source ||
          stored.license != item.license) {
        throw const LocalDataException(
          'Export tham chiếu học liệu thiếu hoặc đã bị thay nội dung.',
        );
      }
      references.add(key);
    }
    return references;
  }
}

class AdminBackup {
  AdminBackup._({
    required this.identity,
    required List<ContentRevision> content,
    required List<AdminInbox> inbox,
    required List<AdminExportSnapshot> exports,
    required Map<String, String> metadata,
    required List<AdminOperationReceipt> receipts,
  }) : content = List.unmodifiable(content),
       inbox = List.unmodifiable(inbox),
       exports = List.unmodifiable(exports),
       metadata = Map.unmodifiable(metadata),
       receipts = List.unmodifiable(receipts);
  factory AdminBackup.create({
    required AdminIdentity identity,
    required List<ContentRevision> content,
    required List<AdminInbox> inbox,
    required List<AdminExportSnapshot> exports,
    required Map<String, String> metadata,
    required List<AdminOperationReceipt> receipts,
  }) {
    final backup = AdminBackup._(
      identity: identity,
      content: content,
      inbox: inbox,
      exports: exports,
      metadata: metadata,
      receipts: receipts,
    );
    backup._validate();
    return backup;
  }
  final AdminIdentity identity;
  final List<ContentRevision> content;
  final List<AdminInbox> inbox;
  final List<AdminExportSnapshot> exports;
  final Map<String, String> metadata;
  final List<AdminOperationReceipt> receipts;
  static Map<String, dynamic> inboxJson(AdminInbox item) => {
    'report': item.report.toJson(),
    'status': item.status.name,
    'receipt': item.receipt?.toJson(),
    'receivedAt': item.receivedAt.toIso8601String(),
  };
  static AdminInbox parseInbox(Map<String, dynamic> j) {
    jsonKeys(j, ['report', 'status', 'receipt', 'receivedAt']);
    final report = FeedbackReport.fromJson(jsonObject(j['report']));
    if (report.state != FeedbackState.recorded || report.outcome != null) {
      throw const LocalDataException('Inbox chỉ giữ snapshot báo lỗi đã nhận.');
    }
    return AdminInbox(
      report: report,
      status: enumValue(InboxStatus.values, j['status']),
      receivedAt: utcValue(j['receivedAt']),
      receipt: j['receipt'] == null
          ? null
          : FeedbackReceipt.fromJson(jsonObject(j['receipt'])),
    );
  }

  Map<String, dynamic> get payload => {
    'format': 'hanyu-admin-backup',
    'formatVersion': 1,
    'identity': identity.toJson(),
    'content': content.map((v) => v.toJson()).toList(),
    'inbox': inbox.map(inboxJson).toList(),
    'exports': exports.map((v) => v.toJson()).toList(),
    'metadata': metadata,
    'receipts': receipts.map((v) => v.toJson()).toList(),
  };
  String get checksum => canonicalChecksum(payload);
  LocalJsonFile toFile() => LocalJsonFile.fromBytes(
    utf8.encode(canonicalJson({...payload, 'checksum': checksum})),
    name: 'hanyu-admin-backup.json',
    kind: LocalJsonKind.adminBackup,
  );
  factory AdminBackup.fromFile(LocalJsonFile file) {
    final j = jsonObject(jsonDecode(file.text));
    jsonKeys(j, [
      'format',
      'formatVersion',
      'identity',
      'content',
      'inbox',
      'exports',
      'metadata',
      'receipts',
      'checksum',
    ]);
    final raw = Map<String, dynamic>.of(j)..remove('checksum');
    if (j['format'] != 'hanyu-admin-backup' ||
        j['formatVersion'] != 1 ||
        canonicalChecksum(raw) != j['checksum']) {
      throw const LocalDataException(
        'Sai định dạng hoặc checksum backup Admin.',
      );
    }
    List<Map<String, dynamic>> rows(String key) {
      final value = j[key];
      if (value is! List) {
        throw const LocalDataException('Danh sách backup không hợp lệ.');
      }
      return value.map(jsonObject).toList();
    }

    final metadata = jsonObject(j['metadata']);
    if (metadata.values.any((v) => v is! String)) {
      throw const LocalDataException('Metadata backup phải là văn bản.');
    }
    final backup = AdminBackup.create(
      identity: AdminIdentity.fromJson(jsonObject(j['identity'])),
      content: rows('content').map(ContentRevision.fromJson).toList(),
      inbox: rows('inbox').map(parseInbox).toList(),
      exports: rows('exports').map(AdminExportSnapshot.fromJson).toList(),
      metadata: metadata.cast<String, String>(),
      receipts: rows('receipts').map(AdminOperationReceipt.fromJson).toList(),
    );
    if (backup.checksum != j['checksum']) {
      throw const LocalDataException(
        'Backup không theo biểu diễn canonical của Hanyu.',
      );
    }
    return backup;
  }
  void _validate() {
    if (content.length > 10000 || inbox.length > 1000) {
      throw const LocalDataException('Backup vượt số lượng dữ liệu cho phép.');
    }
    final records = <String, ContentRevision>{},
        published = <String>{},
        kinds = <String, ContentKind>{};
    for (final record in content) {
      if (records.containsKey('${record.itemId}:${record.revision}') ||
          (kinds[record.itemId] != null &&
              kinds[record.itemId] != record.kind) ||
          (record.state == ContentState.published &&
              !published.add(record.itemId))) {
        throw const LocalDataException(
          'Backup trùng phiên bản hoặc công bố/loại không nhất quán.',
        );
      }
      records['${record.itemId}:${record.revision}'] = record;
      kinds[record.itemId] = record.kind;
      final max = int.tryParse(metadata['content-max:${record.itemId}'] ?? '');
      if (max == null ||
          max < record.revision ||
          metadata['content-kind:${record.itemId}'] != record.kind.name) {
        throw const LocalDataException('Thiếu mốc cấp phiên bản học liệu.');
      }
    }
    final imports = <String, CsvImportResult>{};
    for (final entry in metadata.entries) {
      if (entry.key == 'admin-sample-v1') {
        if (entry.value != 'loaded') {
          throw const LocalDataException('Marker mẫu không hợp lệ.');
        }
        continue;
      }
      if (entry.key.startsWith('csv-import:')) {
        final result = CsvImportResult.fromJson(
          jsonObject(jsonDecode(entry.value)),
        );
        if (entry.key != 'csv-import:${result.operationId}') {
          throw const LocalDataException('Lịch sử nhập CSV sai mã thao tác.');
        }
        for (final id in result.itemIds) {
          if (metadata['content-kind:$id'] != ContentKind.vocabulary.name ||
              int.tryParse(metadata['content-max:$id'] ?? '0') == 0) {
            throw const LocalDataException(
              'Lịch sử nhập tham chiếu từ không có mốc phiên bản.',
            );
          }
        }
        imports[result.operationId] = result;
        continue;
      }
      final match = RegExp(r'^content-(max|kind):(.+)$').firstMatch(entry.key);
      if (match == null) {
        throw const LocalDataException('Metadata không thuộc backup Admin.');
      }
      final id = uuidValue(match.group(2));
      boundedInt(
        int.tryParse(metadata['content-max:$id'] ?? ''),
        1,
        0x7fffffff,
      );
      enumValue(ContentKind.values, metadata['content-kind:$id']);
    }
    final inboxKeys = <String>{};
    for (final entry in inbox) {
      if (!inboxKeys.add('${entry.report.id}:${entry.report.revision}')) {
        throw const LocalDataException('Backup trùng snapshot inbox.');
      }
    }
    final exportKeys = <String>{}, references = <String>{};
    for (final snapshot in exports) {
      if (!exportKeys.add('${snapshot.packageId}:${snapshot.version}')) {
        throw const LocalDataException('Backup trùng export snapshot.');
      }
      references.addAll(snapshot.validate(identity, records));
    }
    if (content.any(
      (v) => v.exported && !references.contains('${v.itemId}:${v.revision}'),
    )) {
      throw const LocalDataException('Bản được pin thiếu export snapshot.');
    }
    if (receipts.map((v) => v.operationId).toSet().length != receipts.length) {
      throw const LocalDataException('Backup trùng mã thao tác.');
    }
    for (final receipt in receipts) {
      final intent = jsonDecode(receipt.fingerprint);
      if (intent is List && intent.isNotEmpty && intent.first == 'csv-import') {
        final summary = imports[receipt.operationId];
        if (summary == null ||
            canonicalJson(intent) !=
                canonicalJson([
                  'csv-import',
                  summary.digest,
                  summary.skipInvalid,
                ])) {
          throw const LocalDataException(
            'Receipt nhập CSV không khớp kết quả đã lưu.',
          );
        }
      }
    }
    for (final summary in imports.values) {
      if (!receipts.any(
        (r) =>
            r.operationId == summary.operationId &&
            r.fingerprint ==
                jsonEncode(['csv-import', summary.digest, summary.skipInvalid]),
      )) {
        throw const LocalDataException(
          'Kết quả nhập CSV thiếu receipt tương ứng.',
        );
      }
    }
    if (utf8.encode(canonicalJson(payload)).length > 8 * 1024 * 1024) {
      throw const LocalDataException('Backup vượt payload Admin 8 MiB.');
    }
  }
}
