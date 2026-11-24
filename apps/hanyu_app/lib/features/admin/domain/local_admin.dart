import '../../content/domain/content_package.dart';
import 'local_csv_import.dart';
import 'content_revision.dart';
import '../../../core/local/local_models.dart';
import '../../support/domain/local_feedback.dart';

enum InboxStatus { open, inProgress, closed }

String inboxStatusLabel(InboxStatus status) => switch (status) {
  InboxStatus.open => 'Mới nhận',
  InboxStatus.inProgress => 'Đang xử lý',
  InboxStatus.closed => 'Đã đóng',
};

class AdminInbox {
  AdminInbox({
    required this.report,
    required this.status,
    required DateTime receivedAt,
    this.receipt,
  }) : receivedAt = receivedAt.toUtc() {
    if ((status == InboxStatus.closed) != (receipt != null) ||
        (receipt != null &&
            !receipt!.matches(report.id, report.revision, report.checksum))) {
      throw const LocalDataException('Trạng thái inbox không khớp kết quả.');
    }
  }
  final FeedbackReport report;
  final InboxStatus status;
  final DateTime receivedAt;
  final FeedbackReceipt? receipt;
}

class LocalAdminSnapshot {
  LocalAdminSnapshot({
    required this.revision,
    required this.identity,
    List<ContentRevision> content = const [],
    List<CsvImportResult> imports = const [],
    List<ContentPackage> packages = const [],
    required List<AdminInbox> inbox,
  }) : inbox = List.unmodifiable(inbox),
       content = List.unmodifiable(content),
       imports = List.unmodifiable(imports),
       packages = List.unmodifiable(packages);
  final int revision;
  final List<AdminInbox> inbox;
  final AdminIdentity identity;
  final List<ContentRevision> content;
  final List<CsvImportResult> imports;
  final List<ContentPackage> packages;
}
