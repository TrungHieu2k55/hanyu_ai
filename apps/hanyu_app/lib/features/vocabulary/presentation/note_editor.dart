import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({super.key, required this.initial});
  final String initial;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late final controller = TextEditingController(text: widget.initial);
  bool finishing = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: !finishing && controller.text != widget.initial,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ghi chú chỉ giữ trong lần mở app này, chưa đồng bộ tài khoản.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          minLines: 4,
          maxLines: 10,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Ghi chú riêng',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (finishing) return;
            final value = controller.text.trim();
            setState(() => finishing = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context, value);
            });
          },
          child: const Text('Giữ ghi chú mẫu'),
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Hủy chỉnh sửa'),
        ),
      ],
    ),
  );
}
