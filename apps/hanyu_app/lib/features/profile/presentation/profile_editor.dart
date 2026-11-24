import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/preview_message.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class ProfileEditor extends StatefulWidget {
  const ProfileEditor({super.key, required this.preferences});
  final LearningPreferences preferences;
  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  late final name = TextEditingController(text: widget.preferences.name);
  bool finishing = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: !finishing && name.text != widget.preferences.name,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Hồ sơ của bạn',
          'Chỉ dùng tên mẫu. Chưa tạo tài khoản hoặc gửi dữ liệu cá nhân.',
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('profile-name'),
          controller: name,
          onChanged: (_) => setState(() {}),
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Tên hiển thị mẫu'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (finishing) return;
            if (name.text.trim().isEmpty) {
              showPreviewMessage(
                context,
                'Nhập tên hiển thị trước khi giữ hồ sơ mẫu.',
              );
              return;
            }
            widget.preferences.name = name.text.trim();
            setState(() => finishing = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          },
          child: const Text('Giữ hồ sơ mẫu'),
        ),
        TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('Hủy chỉnh sửa'),
        ),
      ],
    ),
  );
}
