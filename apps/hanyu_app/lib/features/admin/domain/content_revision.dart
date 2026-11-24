import '../../../core/files/json_contract.dart';
import '../../../core/local/local_models.dart';
import 'content_payload.dart';

enum ReviewStatus { unreviewed, externallyDeclared }

enum ContentState { draft, reviewed, published, superseded, withdrawn }

String contentStateLabel(ContentState state) => switch (state) {
  ContentState.draft => 'Nháp · chưa duyệt',
  ContentState.reviewed => 'Đã khai báo duyệt',
  ContentState.published => 'Đang công bố',
  ContentState.superseded => 'Đã được thay thế',
  ContentState.withdrawn => 'Đã thu hồi',
};

class AdminIdentity {
  AdminIdentity({required String publisherId, String label = ''})
    : publisherId = uuidValue(publisherId),
      label = boundedText(label, 80, empty: true);
  final String publisherId, label;
  Map<String, dynamic> toJson() => {'publisherId': publisherId, 'label': label};
  factory AdminIdentity.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, ['publisherId', 'label']);
    return AdminIdentity(
      publisherId: uuidValue(j['publisherId']),
      label: boundedText(j['label'], 80, empty: true),
    );
  }
}

class ReviewClaim {
  const ReviewClaim.unreviewed()
    : status = ReviewStatus.unreviewed,
      reviewerName = null,
      reviewedRevision = null,
      reviewedAt = null,
      note = null;
  ReviewClaim.declare({
    required String reviewerName,
    required int reviewedRevision,
    required DateTime reviewedAt,
    required String note,
  }) : status = ReviewStatus.externallyDeclared,
       reviewerName = boundedText(reviewerName, 80),
       reviewedRevision = boundedInt(reviewedRevision, 1, 0x7fffffff),
       reviewedAt = reviewedAt.toUtc(),
       note = boundedText(note, 2000);
  final ReviewStatus status;
  final String? reviewerName, note;
  final int? reviewedRevision;
  final DateTime? reviewedAt;
  Map<String, dynamic> toJson() => {
    'status': status.name,
    'reviewerName': reviewerName,
    'reviewedRevision': reviewedRevision,
    'reviewedAt': reviewedAt?.toIso8601String(),
    'note': note,
  };
  factory ReviewClaim.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'status',
      'reviewerName',
      'reviewedRevision',
      'reviewedAt',
      'note',
    ]);
    final status = enumValue(ReviewStatus.values, j['status']);
    if (status == ReviewStatus.unreviewed) {
      if (j.entries.any((e) => e.key != 'status' && e.value != null)) {
        throw const LocalDataException(
          'Bản chưa duyệt không được mang metadata duyệt.',
        );
      }
      return const ReviewClaim.unreviewed();
    }
    return ReviewClaim.declare(
      reviewerName: boundedText(j['reviewerName'], 80),
      reviewedRevision: boundedInt(j['reviewedRevision'], 1, 0x7fffffff),
      reviewedAt: utcValue(j['reviewedAt']),
      note: boundedText(j['note'], 2000),
    );
  }
}

class ContentRevision {
  ContentRevision({
    required String itemId,
    required this.revision,
    required this.payload,
    String source = '',
    String license = '',
    this.review = const ReviewClaim.unreviewed(),
    this.state = ContentState.draft,
    this.exported = false,
    required DateTime createdAt,
  }) : itemId = uuidValue(itemId),
       source = boundedText(source, 2000, empty: true),
       license = boundedText(license, 300, empty: true),
       createdAt = createdAt.toUtc() {
    boundedInt(revision, 1, 0x7fffffff);
    if (state == ContentState.draft) {
      if (review.status != ReviewStatus.unreviewed) {
        throw const LocalDataException('Bản nháp phải bắt đầu chưa duyệt.');
      }
    } else if (review.status != ReviewStatus.externallyDeclared ||
        review.reviewedRevision != revision ||
        this.source.isEmpty ||
        this.license.isEmpty) {
      throw const LocalDataException(
        'Cần nguồn, quyền sử dụng và khai báo duyệt đúng phiên bản.',
      );
    }
  }
  final String itemId, source, license;
  final int revision;
  final ContentPayload payload;
  ContentKind get kind => payload.kind;
  final ReviewClaim review;
  final ContentState state;
  final bool exported;
  final DateTime createdAt;
  ContentRevision withState(ContentState next, {ReviewClaim? claim}) =>
      ContentRevision(
        itemId: itemId,
        revision: revision,
        payload: payload,
        source: source,
        license: license,
        review: claim ?? review,
        state: next,
        exported: exported,
        createdAt: createdAt,
      );
  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'revision': revision,
    'kind': kind.name,
    'payload': payload.toJson(),
    'source': source,
    'license': license,
    'review': review.toJson(),
    'state': state.name,
    'exported': exported,
    'createdAt': createdAt.toIso8601String(),
  };
  factory ContentRevision.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'itemId',
      'revision',
      'kind',
      'payload',
      'source',
      'license',
      'review',
      'state',
      'exported',
      'createdAt',
    ]);
    if (j['exported'] is! bool) {
      throw const LocalDataException('Trạng thái pin không hợp lệ.');
    }
    return ContentRevision(
      itemId: uuidValue(j['itemId']),
      revision: boundedInt(j['revision'], 1, 0x7fffffff),
      payload: ContentPayload.fromJson(
        enumValue(ContentKind.values, j['kind']),
        jsonObject(j['payload']),
      ),
      source: boundedText(j['source'], 2000, empty: true),
      license: boundedText(j['license'], 300, empty: true),
      review: ReviewClaim.fromJson(jsonObject(j['review'])),
      state: enumValue(ContentState.values, j['state']),
      exported: j['exported'] as bool,
      createdAt: utcValue(j['createdAt']),
    );
  }
}
