import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

enum DeletionPreviewStage {
  introduction,
  received,
  processing,
  completed,
  failed,
}

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool acknowledged = false;
  DeletionPreviewStage stage = DeletionPreviewStage.introduction;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Quy trình xóa tài khoản',
        'Luồng minh họa: chưa gửi yêu cầu, không xóa dữ liệu hoặc đăng xuất tài khoản thật.',
      ),
      const SizedBox(height: 24),
      if (stage == DeletionPreviewStage.introduction) ...[
        const PanelCard(
          child: Text(
            'Phạm vi dự kiến: hồ sơ, tiến độ, từ/ghi chú riêng, lịch sử và media thuộc tài khoản theo chính sách được duyệt.\n\nHọc liệu chung không bị xóa. Xóa một ảnh/audio riêng là thao tác khác.\n\nBản thật phải đăng nhập/xác thực lại trước khi gửi yêu cầu.',
          ),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: acknowledged,
          onChanged: (v) => setState(() => acknowledged = v ?? false),
          title: const Text(
            'Tôi hiểu đây là luồng minh họa, chưa gửi yêu cầu.',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: acknowledged
              ? () => setState(() => stage = DeletionPreviewStage.received)
              : null,
          child: const Text('Xem xác nhận minh họa'),
        ),
      ] else ...[
        DeletionStatusCard(stage: stage),
        const SizedBox(height: 20),
        if (stage == DeletionPreviewStage.received)
          FilledButton(
            onPressed: () =>
                setState(() => stage = DeletionPreviewStage.processing),
            child: const Text('Xem trạng thái đang xử lý (mẫu)'),
          ),
        if (stage == DeletionPreviewStage.processing) ...[
          FilledButton(
            onPressed: () =>
                setState(() => stage = DeletionPreviewStage.completed),
            child: const Text('Xem hoàn tất (mẫu)'),
          ),
          TextButton(
            onPressed: () =>
                setState(() => stage = DeletionPreviewStage.failed),
            child: const Text('Xem lỗi xử lý (mẫu)'),
          ),
        ],
        if (stage == DeletionPreviewStage.failed)
          FilledButton(
            onPressed: () =>
                setState(() => stage = DeletionPreviewStage.processing),
            child: const Text('Xem lại bước xử lý (mẫu)'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Về quyền riêng tư'),
        ),
      ],
    ],
  );
}

class DeletionStatusCard extends StatelessWidget {
  const DeletionStatusCard({required this.stage, super.key});
  final DeletionPreviewStage stage;
  @override
  Widget build(BuildContext context) {
    final (icon, title, detail) = switch (stage) {
      DeletionPreviewStage.introduction || DeletionPreviewStage.received => (
        Icons.info_outline,
        'Chưa gửi yêu cầu xóa',
        'Vị trí hiển thị biên nhận sau khi kết nối backend. Không có mã yêu cầu thật nào được tạo.',
      ),
      DeletionPreviewStage.processing => (
        Icons.hourglass_empty,
        'Đang xử lý · trạng thái mẫu',
        'Bản thật sẽ hiển thị tiến trình tác vụ. Bản này không có tác vụ xóa đang chạy.',
      ),
      DeletionPreviewStage.completed => (
        Icons.task_alt,
        'Hoàn tất · trạng thái mẫu',
        'Đây là cách trình bày khi tác vụ thật hoàn tất. Dữ liệu và phiên đăng nhập của bạn chưa bị thay đổi.',
      ),
      DeletionPreviewStage.failed => (
        Icons.error_outline,
        'Chưa xử lý được · trạng thái mẫu',
        'Bản thật cần mã lỗi và hướng xử lý từ backend. Bạn đang xem ví dụ giao diện, không phải lỗi của tài khoản.',
      ),
    };
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 36),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(detail),
        ],
      ),
    );
  }
}
