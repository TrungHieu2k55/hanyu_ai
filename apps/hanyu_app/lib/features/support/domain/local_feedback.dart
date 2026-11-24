import 'dart:convert';

import '../../../core/files/canonical_json.dart';
import '../../../core/files/local_file_transfer.dart';
import '../../../core/local/local_models.dart';

enum FeedbackState { draft, recorded, exported, resolvedImported }

String feedbackStateLabel(FeedbackState state) => switch (state) {
  FeedbackState.draft => 'Nháp trên thiết bị',
  FeedbackState.recorded => 'Đã lưu, chưa ghi nhận xuất',
  FeedbackState.exported => 'Đã bàn giao file cho hệ thống',
  FeedbackState.resolvedImported => 'Đã nhập kết quả xử lý',
};

class FeedbackContext {
  FeedbackContext(Map<String, String> values)
    : values = Map.unmodifiable(values) {
    if (values.keys.any(
          (k) => !const [
            'contentId',
            'contentVersion',
            'label',
            'route',
          ].contains(k),
        ) ||
        utf8.encode(canonicalJson(values)).length > 2048) {
      throw const LocalDataException(
        'Ngữ cảnh báo lỗi không hợp lệ hoặc quá dài.',
      );
    }
  }
  factory FeedbackContext.fromJson(Object? value) {
    final map = feedbackObject(value);
    if (map.values.any((v) => v is! String)) {
      throw const LocalDataException('Ngữ cảnh chỉ nhận văn bản.');
    }
    return FeedbackContext(map.cast<String, String>());
  }
  final Map<String, String> values;
}

class FeedbackReport {
  const FeedbackReport._({
    required this.id,
    required this.revision,
    required this.body,
    required this.context,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
    required this.checksum,
    required this.outcome,
  });

  factory FeedbackReport.create({
    required String id,
    required int revision,
    required String body,
    FeedbackContext? context,
    required DateTime createdAt,
    required DateTime updatedAt,
    FeedbackState state = FeedbackState.draft,
    FeedbackReceipt? outcome,
  }) {
    _uuid(id);
    final text = body.trim();
    if (revision < 1 ||
        text.runes.length > 2000 ||
        (state != FeedbackState.draft && text.isEmpty) ||
        updatedAt.isBefore(createdAt)) {
      throw const LocalDataException(
        'Nội dung hoặc phiên bản báo lỗi không hợp lệ.',
      );
    }
    final payload = _payload(id, revision, text, context, createdAt, updatedAt);
    final checksum = canonicalChecksum(payload);
    if ((state == FeedbackState.resolvedImported) != (outcome != null) ||
        (outcome != null && !outcome.matches(id, revision, checksum))) {
      throw const LocalDataException('Kết quả không khớp báo lỗi.');
    }
    return FeedbackReport._(
      id: id,
      revision: revision,
      body: text,
      context: context,
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      state: state,
      checksum: checksum,
      outcome: outcome,
    );
  }

  final String id, body, checksum;
  final int revision;
  final FeedbackContext? context;
  final DateTime createdAt, updatedAt;
  final FeedbackState state;
  final FeedbackReceipt? outcome;

  static Map<String, dynamic> _payload(
    String id,
    int revision,
    String body,
    FeedbackContext? context,
    DateTime created,
    DateTime updated,
  ) => {
    'id': id,
    'revision': revision,
    'body': body,
    'context': context?.values,
    'createdAt': created.toUtc().toIso8601String(),
    'updatedAt': updated.toUtc().toIso8601String(),
  };
  Map<String, dynamic> get payload =>
      _payload(id, revision, body, context, createdAt, updatedAt);
  Map<String, dynamic> toTransferJson() => {...payload, 'checksum': checksum};
  Map<String, dynamic> toJson() => {
    ...toTransferJson(),
    'state': state.name,
    'outcome': outcome?.toJson(),
  };

  FeedbackReport withState(FeedbackState next, {FeedbackReceipt? outcome}) =>
      FeedbackReport.create(
        id: id,
        revision: revision,
        body: body,
        context: context,
        createdAt: createdAt,
        updatedAt: updatedAt,
        state: next,
        outcome: outcome,
      );

  LocalJsonFile toFile() {
    if (state == FeedbackState.draft) {
      throw const LocalDataException('Hoàn tất báo lỗi trước khi xuất.');
    }
    return _file({
      'format': 'hanyu-feedback',
      'formatVersion': 1,
      'report': toTransferJson(),
    }, 'hanyu-feedback-$id-v$revision.json');
  }

  factory FeedbackReport.fromFile(LocalJsonFile file) {
    final data = feedbackObject(jsonDecode(file.text));
    feedbackKeys(data, ['format', 'formatVersion', 'report']);
    if (data['format'] != 'hanyu-feedback' || data['formatVersion'] != 1) {
      throw const LocalDataException('Đây không phải tệp báo lỗi Hanyu.');
    }
    return FeedbackReport._parse(feedbackObject(data['report']), stored: false);
  }
  factory FeedbackReport.fromJson(Map<String, dynamic> data) =>
      FeedbackReport._parse(data, stored: true);
  factory FeedbackReport._parse(
    Map<String, dynamic> data, {
    required bool stored,
  }) {
    feedbackKeys(data, [
      'id',
      'revision',
      'body',
      'context',
      'createdAt',
      'updatedAt',
      'checksum',
      if (stored) 'state',
      if (stored) 'outcome',
    ]);
    final state = stored
        ? FeedbackState.values.where((v) => v.name == data['state']).firstOrNull
        : FeedbackState.recorded;
    if (state == null) {
      throw const LocalDataException('Trạng thái báo lỗi không hợp lệ.');
    }
    final report = FeedbackReport.create(
      id: feedbackText(data['id'], 100),
      revision: feedbackInt(data['revision']),
      body: feedbackText(
        data['body'],
        2000,
        empty: state == FeedbackState.draft,
      ),
      context: data['context'] == null
          ? null
          : FeedbackContext.fromJson(data['context']),
      createdAt: feedbackUtc(data['createdAt']),
      updatedAt: feedbackUtc(data['updatedAt']),
      state: state,
      outcome: stored && data['outcome'] != null
          ? FeedbackReceipt.fromJson(feedbackObject(data['outcome']))
          : null,
    );
    if (report.checksum != data['checksum']) {
      throw const LocalDataException('Nội dung báo lỗi không khớp checksum.');
    }
    return report;
  }
}

class FeedbackReceipt {
  FeedbackReceipt({
    required this.reportId,
    required this.reportRevision,
    required this.reportChecksum,
    required String resolution,
    required String actorLabel,
    required DateTime closedAt,
  }) : resolution = feedbackText(resolution, 2000),
       actorLabel = feedbackText(actorLabel, 80),
       closedAt = closedAt.toUtc() {
    _uuid(reportId);
    if (reportRevision < 1 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(reportChecksum)) {
      throw const LocalDataException('Mã báo lỗi trong kết quả không hợp lệ.');
    }
  }
  final String reportId, reportChecksum, resolution, actorLabel;
  final int reportRevision;
  final DateTime closedAt;
  bool matches(String id, int revision, String checksum) =>
      reportId == id &&
      reportRevision == revision &&
      reportChecksum == checksum;
  Map<String, dynamic> toJson() => {
    'reportId': reportId,
    'reportRevision': reportRevision,
    'reportChecksum': reportChecksum,
    'resolution': resolution,
    'actorLabel': actorLabel,
    'closedAt': closedAt.toIso8601String(),
  };
  factory FeedbackReceipt.fromJson(Map<String, dynamic> data) {
    feedbackKeys(data, [
      'reportId',
      'reportRevision',
      'reportChecksum',
      'resolution',
      'actorLabel',
      'closedAt',
    ]);
    return FeedbackReceipt(
      reportId: feedbackText(data['reportId'], 100),
      reportRevision: feedbackInt(data['reportRevision']),
      reportChecksum: feedbackText(data['reportChecksum'], 64),
      resolution: feedbackText(data['resolution'], 2000),
      actorLabel: feedbackText(data['actorLabel'], 80),
      closedAt: feedbackUtc(data['closedAt']),
    );
  }
  LocalJsonFile toFile() => _file({
    'format': 'hanyu-feedback-receipt',
    'formatVersion': 1,
    'receipt': toJson(),
  }, 'hanyu-feedback-result-$reportId-v$reportRevision.json');
  factory FeedbackReceipt.fromFile(LocalJsonFile file) {
    final data = feedbackObject(jsonDecode(file.text));
    feedbackKeys(data, ['format', 'formatVersion', 'receipt']);
    if (data['format'] != 'hanyu-feedback-receipt' ||
        data['formatVersion'] != 1) {
      throw const LocalDataException(
        'Đây không phải tệp kết quả báo lỗi Hanyu.',
      );
    }
    return FeedbackReceipt.fromJson(feedbackObject(data['receipt']));
  }
}

LocalJsonFile _file(Map<String, dynamic> data, String name) =>
    LocalJsonFile.fromBytes(
      utf8.encode(canonicalJson(data)),
      name: name,
      kind: LocalJsonKind.feedback,
    );
Map<String, dynamic> feedbackObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const LocalDataException('Dữ liệu báo lỗi phải là object JSON.');
  }
  return value;
}

void feedbackKeys(Map<String, dynamic> data, List<String> keys) {
  if (data.length != keys.length || data.keys.any((k) => !keys.contains(k))) {
    throw const LocalDataException(
      'Tệp thiếu trường hoặc có trường ngoài hợp đồng.',
    );
  }
}

String feedbackText(Object? value, int max, {bool empty = false}) {
  if (value is! String ||
      value.trim().runes.length > max ||
      (!empty && value.trim().isEmpty)) {
    throw const LocalDataException(
      'Văn bản báo lỗi hoặc kết quả không hợp lệ.',
    );
  }
  return value.trim();
}

int feedbackInt(Object? value) {
  if (value is! int || value < 1) {
    throw const LocalDataException('Phiên bản báo lỗi không hợp lệ.');
  }
  return value;
}

DateTime feedbackUtc(Object? value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc || date.toIso8601String() != value) {
    throw const LocalDataException(
      'Thời gian phải theo UTC ISO8601 chuẩn của Hanyu.',
    );
  }
  return date;
}

void _uuid(String value) {
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(value)) {
    throw const LocalDataException('Mã báo lỗi phải là UUID hợp lệ.');
  }
}
