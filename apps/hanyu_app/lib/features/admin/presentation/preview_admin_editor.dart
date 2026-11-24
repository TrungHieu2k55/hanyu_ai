import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class PreviewAdminEditor extends StatefulWidget {
  const PreviewAdminEditor({
    super.key,
    required this.initial,
    required this.kind,
  });
  final Map<String, String> initial;
  final String kind;
  @override
  State<PreviewAdminEditor> createState() => _PreviewAdminEditorState();
}

class _PreviewAdminEditorState extends State<PreviewAdminEditor> {
  late final fields = widget.initial.map(
    (key, value) => MapEntry(key, TextEditingController(text: value)),
  );
  final form = GlobalKey<FormState>();
  bool finishing = false;
  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty:
        !finishing &&
        fields.entries.any((e) => e.value.text != widget.initial[e.key]),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Editor ${widget.kind}',
            'Giữ bản ghi ở trạng thái nháp. Chưa đồng bộ hoặc thay đổi học liệu của học viên.',
          ),
          const SizedBox(height: 24),
          for (final field in fields.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: field.value,
                onChanged: (_) => setState(() {}),
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: field.key,
                  helperText: field.key == 'Nguồn / giấy phép'
                      ? 'Có thể để trống ở bản nháp; phải xác minh trước khi công bố thật.'
                      : null,
                ),
                validator: (value) {
                  if (field.key != 'Nguồn / giấy phép' &&
                      (value?.trim().isEmpty ?? true)) {
                    return 'Không được để trống.';
                  }
                  if (field.key == 'Đáp án A/B/C' &&
                      !['A', 'B', 'C'].contains(value?.trim().toUpperCase())) {
                    return 'Chọn A, B hoặc C.';
                  }
                  return null;
                },
              ),
            ),
          FilledButton(
            onPressed: () {
              if (finishing || !form.currentState!.validate()) return;
              final result = fields.map(
                (key, value) => MapEntry(key, value.text.trim()),
              );
              setState(() => finishing = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.pop(context, result);
              });
            },
            child: const Text('Giữ nháp mẫu'),
          ),
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Hủy chỉnh sửa'),
          ),
        ],
      ),
    ),
  );
}
