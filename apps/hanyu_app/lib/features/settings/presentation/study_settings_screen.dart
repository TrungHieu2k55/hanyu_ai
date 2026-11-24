import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class StudySettingsScreen extends StatefulWidget {
  const StudySettingsScreen({super.key, required this.preferences});
  final LearningPreferences preferences;
  @override
  State<StudySettingsScreen> createState() => _StudySettingsScreenState();
}

class _StudySettingsScreenState extends State<StudySettingsScreen> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      buildPageTitle(
        'Một nhịp học vừa sức',
        'Giữ lựa chọn trong lần mở app này. Chưa lưu vào tài khoản.',
      ),
      const SizedBox(height: 24),
      const Text('Mục tiêu HSK', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (var i = 1; i <= 3; i++)
            ChoiceChip(
              label: Text('HSK $i'),
              selected: widget.preferences.level == i,
              onSelected: (_) => setState(() => widget.preferences.level = i),
            ),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'Thời lượng mỗi ngày',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (final m in [5, 15, 30])
            ChoiceChip(
              label: Text('$m phút'),
              selected: widget.preferences.minutes == m,
              onSelected: (_) => setState(() => widget.preferences.minutes = m),
            ),
        ],
      ),
      const SizedBox(height: 20),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Âm thanh hướng dẫn'),
        subtitle: const Text('Tùy chọn mẫu; chưa có audio.'),
        value: widget.preferences.sound,
        onChanged: (v) => setState(() => widget.preferences.sound = v),
      ),
    ],
  );
}
