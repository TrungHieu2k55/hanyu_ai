import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.contextLabel});
  final String? contextLabel;
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final controller = TextEditingController();
  bool checked = false;
  bool? deliveredPreview;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: controller.text.isNotEmpty,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Góp ý để học tốt hơn',
          'Bản nháp này chưa gửi cho quản trị viên.',
        ),
        const SizedBox(height: 20),
        if (widget.contextLabel != null) ...[
          Text(
            'Nội dung: ${widget.contextLabel}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {
            checked = false;
            deliveredPreview = null;
          }),
          minLines: 4,
          maxLines: 10,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Mô tả vấn đề',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isEmpty) {
              showPreviewMessage(context, 'Nhập mô tả trước khi xem lại.');
              return;
            }
            setState(() => checked = true);
          },
          child: const Text('Xem lại bản nháp'),
        ),
        if (checked) ...[
          const SizedBox(height: 20),
          PanelCard(
            child: Text(
              'Bản nháp:\n${controller.text.trim()}\n\nChưa gửi — cần kết nối dịch vụ phản hồi.',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () async {
              final outcome = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Xem kết quả gửi minh họa?'),
                  content: const Text(
                    'Không gửi dữ liệu thật. Chọn trạng thái để xem cách ứng dụng giữ bản nháp và hỗ trợ thử lại.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Xem lỗi mẫu'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Xem đã nhận mẫu'),
                    ),
                  ],
                ),
              );
              if (outcome != null && mounted) {
                setState(() => deliveredPreview = outcome);
              }
            },
            child: Text(
              deliveredPreview == false
                  ? 'Xem thử lại, giữ bản nháp'
                  : 'Xem trạng thái gửi mẫu',
            ),
          ),
          if (deliveredPreview != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                deliveredPreview!
                    ? 'Đã xem trạng thái tiếp nhận mẫu. Không có phản hồi thật được gửi; bản nháp vẫn giữ trên màn này.'
                    : 'Lỗi gửi minh họa. Nội dung và ngữ cảnh vẫn giữ; có thể sửa hoặc xem thử lại. Không có dữ liệu nào được gửi.',
              ),
            ),
          ],
        ],
      ],
    ),
  );
}
