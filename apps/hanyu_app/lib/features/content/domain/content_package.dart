import 'dart:convert';
import 'dart:typed_data';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/json_contract.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';
import '../../admin/domain/content_payload.dart';
import '../../admin/domain/content_revision.dart';

enum PackageMode { trial, reviewed }

/// Text-only handoff contract. A checksum detects changes, never authenticates a publisher.
class ContentPackage {
  ContentPackage._({
    required this.publisherId,
    required this.packageId,
    required this.version,
    required this.mode,
    required this.exportedAt,
    required List<ContentRevision> records,
  }) : records = List.unmodifiable(records);

  factory ContentPackage.create({
    required String publisherId,
    required String packageId,
    required int version,
    required PackageMode mode,
    required DateTime exportedAt,
    required List<ContentRevision> records,
  }) {
    final result = ContentPackage._(
      publisherId: uuidValue(publisherId),
      packageId: uuidValue(packageId),
      version: boundedInt(version, 1, 0x7fffffff),
      mode: mode,
      exportedAt: exportedAt.toUtc(),
      records: records,
    );
    result._validate();
    if (utf8.encode(canonicalJson(result.toJson())).length >
        LocalJsonKind.contentPackage.maxBytes) {
      throw const LocalDataException(
        'Gói vượt giới hạn 2 MiB. Chia thành gói nhỏ hơn.',
      );
    }
    return result;
  }
  final String publisherId, packageId;
  final int version;
  final PackageMode mode;
  final DateTime exportedAt;
  final List<ContentRevision> records;
  String get checksum => canonicalChecksum(_payload());
  String wordId(String itemId) => 'content:$publisherId:${uuidValue(itemId)}';
  int count(ContentKind kind) => records.where((r) => r.kind == kind).length;

  /// Internal pin/timestamps do not cross the package boundary.
  static Map<String, dynamic> recordJson(ContentRevision record) => {
    'itemId': record.itemId,
    'revision': record.revision,
    'kind': record.kind.name,
    'payload': record.payload.toJson(),
    'source': record.source,
    'license': record.license,
    'review': record.review.toJson(),
    'state': record.state.name,
  };
  static ContentRevision readRecord(Object? raw, DateTime exportedAt) {
    final row = jsonObject(raw);
    jsonKeys(row, [
      'itemId',
      'revision',
      'kind',
      'payload',
      'source',
      'license',
      'review',
      'state',
    ]);
    return ContentRevision.fromJson({
      ...row,
      'createdAt': exportedAt.toIso8601String(),
      'exported': true,
    });
  }

  Map<String, dynamic> _payload() => {
    'format': 'hanyu-content-package',
    'formatVersion': 1,
    'publisherId': publisherId,
    'packageId': packageId,
    'version': version,
    'mode': mode.name,
    'exportedAt': exportedAt.toIso8601String(),
    'records': records.map(recordJson).toList(),
  };
  Map<String, dynamic> toJson() => {..._payload(), 'checksum': checksum};
  factory ContentPackage.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'format',
      'formatVersion',
      'publisherId',
      'packageId',
      'version',
      'mode',
      'exportedAt',
      'records',
      'checksum',
    ]);
    if (j['format'] != 'hanyu-content-package' ||
        j['formatVersion'] is! int ||
        j['formatVersion'] != 1) {
      throw const LocalDataException('Đây không phải gói học liệu văn bản v1.');
    }
    final records = j['records'];
    if (records is! List || records.length > 1064) {
      throw const LocalDataException('Danh sách học liệu không hợp lệ.');
    }
    final raw = Map<String, dynamic>.of(j)..remove('checksum');
    if (j['checksum'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(j['checksum']) ||
        canonicalChecksum(raw) != j['checksum']) {
      throw const LocalDataException(
        'Checksum không khớp; gói đã thay đổi hoặc hỏng.',
      );
    }
    final time = utcValue(j['exportedAt']);
    final p = ContentPackage.create(
      publisherId: uuidValue(j['publisherId']),
      packageId: uuidValue(j['packageId']),
      version: boundedInt(j['version'], 1, 0x7fffffff),
      mode: enumValue(PackageMode.values, j['mode']),
      exportedAt: time,
      records: records.map((r) => readRecord(r, time)).toList(),
    );
    // Reject values that normalize to different bytes instead of silently changing the contract.
    if (p.checksum != j['checksum']) {
      throw const LocalDataException(
        'Giá trị trong gói chưa theo định dạng chuẩn.',
      );
    }
    return p;
  }
  factory ContentPackage.fromFile(LocalJsonFile input) {
    final file = LocalJsonFile.fromBytes(
      input.bytes,
      name: input.name,
      kind: LocalJsonKind.contentPackage,
    );
    return ContentPackage.fromJson(jsonObject(jsonDecode(file.text)));
  }
  LocalJsonFile toFile() => LocalJsonFile.fromBytes(
    Uint8List.fromList(utf8.encode(canonicalJson(toJson()))),
    name: 'hanyu-$packageId-v$version.json',
    kind: LocalJsonKind.contentPackage,
  );

  void _validate() {
    if (records.length > 1064) {
      throw const LocalDataException('Gói có quá nhiều học liệu.');
    }
    final ids = <String>{}, slots = <String>{}, scenarios = <String>{};
    for (final item in records) {
      if (!ids.add(item.itemId)) {
        throw const LocalDataException(
          'Một gói chỉ chứa một phiên bản mỗi học liệu.',
        );
      }
      if (![
            ContentState.draft,
            ContentState.reviewed,
            ContentState.published,
          ].contains(item.state) ||
          (mode == PackageMode.reviewed &&
              item.state != ContentState.published)) {
        throw const LocalDataException(
          'Gói đã duyệt chỉ nhận bản đang công bố; không xuất bản đã thu hồi/thay thế.',
        );
      }
      if (item.payload case final QuestionContent q) {
        if (!slots.add('${q.targetLevel}:${q.section}:${q.slot}')) {
          throw const LocalDataException('Gói trùng vị trí câu hỏi.');
        }
      }
      if (item.payload case final ScenarioContent s) {
        if (!scenarios.add(s.key)) {
          throw const LocalDataException('Gói trùng tình huống.');
        }
      }
    }
    if (count(ContentKind.vocabulary) > 1000 ||
        count(ContentKind.question) > 60 ||
        count(ContentKind.scenario) > 4) {
      throw const LocalDataException(
        'Mỗi gói tối đa 1.000 từ, 60 câu hỏi và 4 tình huống.',
      );
    }
  }
}
