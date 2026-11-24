import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';

enum PreviewState {
  loading,
  offline,
  retryableError,
  expired,
  forbidden,
  empty,
  missingMedia,
  notConfigured,
}

class PreviewStatusPanel extends StatelessWidget {
  const PreviewStatusPanel({
    required this.state,
    this.onAction,
    this.message,
    super.key,
  });
  final PreviewState state;
  final VoidCallback? onAction;
  final String? message;
  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, action) = switch (state) {
      PreviewState.loading => (
        Icons.hourglass_empty,
        'Đang xử lý',
        'Giữ màn hình này hoặc quay lại sau. Không gửi lại cùng thao tác.',
        null,
      ),
      PreviewState.offline => (
        Icons.wifi_off,
        'Chưa có kết nối',
        'Nội dung đang nhập cần được giữ lại. Kiểm tra kết nối rồi thử lại.',
        'Thử lại',
      ),
      PreviewState.retryableError => (
        Icons.refresh,
        'Chưa nhận được kết quả',
        'Tác vụ có thể vẫn đang xử lý. Kiểm tra trạng thái trước khi gửi lại.',
        'Kiểm tra lại',
      ),
      PreviewState.expired => (
        Icons.lock_clock_outlined,
        'Cần đăng nhập lại',
        'Phiên đã hết hạn. Đăng nhập để tiếp tục thao tác đang làm.',
        'Đăng nhập lại',
      ),
      PreviewState.forbidden => (
        Icons.lock_outline,
        'Bạn chưa có quyền truy cập',
        'Quay lại khu vực được phép hoặc liên hệ hỗ trợ nếu cần.',
        'Quay lại',
      ),
      PreviewState.empty => (
        Icons.inbox_outlined,
        'Chưa có nội dung',
        'Bắt đầu một hoạt động để xem dữ liệu ở đây.',
        'Khám phá bài học',
      ),
      PreviewState.missingMedia => (
        Icons.volume_off_outlined,
        'Chưa có tệp audio',
        'Bạn vẫn có thể đọc văn bản thay thế. Không có âm thanh nào được phát trong bản mẫu.',
        null,
      ),
      PreviewState.notConfigured => (
        Icons.construction_outlined,
        'Tính năng chưa được kết nối',
        'Bản giao diện chưa gọi dịch vụ xử lý thật. Nội dung mẫu không phải kết quả AI.',
        null,
      ),
    };
    return StatusPanel(
      icon: icon,
      title: title,
      message: message ?? detail,
      loading: state == PreviewState.loading,
      actionLabel: action,
      onAction: onAction,
    );
  }
}

class StatusPanel extends StatelessWidget {
  const StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.illustration,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final Widget? illustration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(),
            )
          else
            ExcludeSemantics(
              child: illustration ?? Icon(icon, size: 28, color: brandTeal),
            ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(message),
          if (actionLabel case final label? when onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(label)),
          ],
        ],
      ),
    ),
  );
}
