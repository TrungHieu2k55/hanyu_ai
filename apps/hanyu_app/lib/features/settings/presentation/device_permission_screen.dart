import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class DevicePermissionScreen extends StatelessWidget {
  const DevicePermissionScreen({this.onPhoto, this.onConversation, super.key});

  final VoidCallback? onPhoto;
  final VoidCallback? onConversation;

  bool get preview => onPhoto == null && onConversation == null;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        preview ? 'Quyền thiết bị' : 'Camera và microphone',
        preview
            ? 'Bản mẫu chưa truy cập hoặc kiểm tra camera/microphone của bạn.'
            : 'Ứng dụng chỉ hỏi quyền khi bạn mở camera hoặc bắt đầu ghi âm.',
      ),
      const SizedBox(height: 24),
      for (final entry in [
        (
          Icons.camera_alt_outlined,
          'Camera',
          'Dùng khi bạn chủ động chụp chữ. Bạn cũng có thể chọn ảnh có sẵn hoặc nhập văn bản.',
        ),
        (
          Icons.mic_none,
          'Microphone',
          'Dùng khi bạn chủ động ghi âm hội thoại. Có thể nhập câu trả lời bằng chữ.',
        ),
      ]) ...[
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(entry.$1, size: 32, color: brandTeal),
              const SizedBox(height: 12),
              Text(
                entry.$2,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(entry.$3),
              const SizedBox(height: 12),
              if (preview)
                const Text(
                  'Trạng thái: bản mẫu chưa kiểm tra quyền.',
                  style: TextStyle(color: mutedText, fontSize: 14),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (onPhoto != null)
        OutlinedButton(
          onPressed: onPhoto,
          child: const Text('Chọn nguồn ảnh khác'),
        ),
      if (onConversation != null)
        OutlinedButton(
          onPressed: onConversation,
          child: const Text('Nhập chữ để hội thoại'),
        ),
      OutlinedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Nếu quyền bị từ chối'),
            content: const Text(
              'Kiểm tra quyền camera hoặc microphone của ứng dụng/trang web trong phần cài đặt trình duyệt hay thiết bị. Sau khi cấp quyền, quay lại thao tác và thử lại.\n\nBạn có thể tiếp tục bằng ảnh có sẵn hoặc nhập chữ.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        ),
        child: const Text('Xem hướng dẫn quyền bị từ chối'),
      ),
    ],
  );
}
