import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';

class ConfirmTurnScreen extends StatefulWidget {
  const ConfirmTurnScreen({
    super.key,
    required this.initial,
    required this.onDraftChanged,
  });
  final String initial;
  final ValueChanged<String> onDraftChanged;
  @override
  State<ConfirmTurnScreen> createState() => _ConfirmTurnScreenState();
}

class _ConfirmTurnScreenState extends State<ConfirmTurnScreen> {
  late final controller = TextEditingController(text: widget.initial);
  bool submitting = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Kiểm tra rồi xác nhận',
        'Bạn có thể sửa câu tại đây. Chưa có audio hoặc transcript do AI tạo.',
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey('confirm-turn-input'),
        controller: controller,
        onChanged: widget.onDraftChanged,
        minLines: 3,
        maxLines: 8,
        maxLength: 300,
        decoration: const InputDecoration(
          labelText: 'Câu sẽ được thêm vào phiên mẫu',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: submitting
            ? null
            : () {
                if (submitting) return;
                final text = controller.text.trim();
                if (text.isEmpty) {
                  showPreviewMessage(
                    context,
                    'Câu trả lời không được để trống.',
                  );
                  return;
                }
                submitting = true;
                Navigator.pop(context, text);
              },
        child: const Text('Xác nhận lượt mẫu'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy — về bản nháp'),
      ),
    ],
  );
}
