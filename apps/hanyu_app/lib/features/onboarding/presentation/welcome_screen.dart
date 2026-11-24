import 'package:flutter/material.dart';

import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../auth/presentation/account_scaffold.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../settings/domain/learning_preferences.dart';
import 'guest_preview_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({this.preferences, super.key});

  final LearningPreferences? preferences;

  void openAccount(BuildContext context, {bool register = false}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AuthScreen(
            preferences: preferences,
            startInRegistration: register,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AccountScaffold(
    title: 'Chào mừng đến Hanyu',
    action: FilledButton(
      onPressed: () => openAccount(context, register: true),
      child: const Text('Bắt đầu học'),
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const BrandMark(large: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hanyu AI',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Gặp một chữ mới.\nBiến nó thành điều bạn nhớ.',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: brandInk, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tra từ, luyện nét và dùng tiếng Trung trong những cuộc trò chuyện gần gũi.',
        ),
        const SizedBox(height: 16),
        const LearnerSurface(
          color: softSurface,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _LearningTile('学', 'Khám phá'),
              _LearningTile('写', 'Luyện viết'),
              _LearningTile('说', 'Trò chuyện'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const LearnerSurface(
          color: softSurface,
          child: Text('Từ bạn gặp có thể được lưu vào bộ ôn của riêng mình.'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => openAccount(context),
          child: const Text('Đã có tài khoản? Đăng nhập'),
        ),
        TextButton(
          onPressed: () async {
            final completed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const _LearningGuide()),
            );
            if (completed == true && context.mounted) Navigator.pop(context);
          },
          child: const Text('Xem hướng dẫn từng bước'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => const GuestPreviewScreen()),
          ),
          child: const Text('Xem thử không cần tài khoản'),
        ),
      ],
    ),
  );
}

class _LearningTile extends StatelessWidget {
  const _LearningTile(this.hanzi, this.label);
  final String hanzi;
  final String label;

  @override
  Widget build(BuildContext context) => LearnerSurface(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Text(
          hanzi,
          style: const TextStyle(
            fontFamily: 'Noto Sans SC',
            fontWeight: FontWeight.w700,
            fontSize: 36,
            color: brandInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: mutedText)),
      ],
    ),
  );
}

class _LearningGuide extends StatefulWidget {
  const _LearningGuide();

  @override
  State<_LearningGuide> createState() => _LearningGuideState();
}

class _LearningGuideState extends State<_LearningGuide> {
  int step = 0;

  static const steps = [
    (
      'Học từng từ, dùng từng câu',
      'Tra từ, xem Pinyin và nghĩa Việt rồi lưu vào bộ ôn.',
    ),
    (
      'Viết, nhìn và nói',
      'Thử viết chữ trên ô vuông, đọc chữ trong ảnh và hội thoại theo tình huống.',
    ),
    (
      'Giữ nhịp học của bạn',
      'Đặt mục tiêu vừa sức. Dữ liệu khu xem mẫu chỉ giữ trong lần mở app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final (title, detail) = steps[step];
    final last = step == steps.length - 1;
    return AccountScaffold(
      title: 'Hướng dẫn ${step + 1} / ${steps.length}',
      action: FilledButton(
        onPressed: last
            ? () => Navigator.pop(context, true)
            : () => setState(() => step++),
        child: Text(last ? 'Hoàn tất xem hướng dẫn' : 'Tiếp theo'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(detail),
          if (step > 0)
            TextButton(
              onPressed: () => setState(() => step--),
              child: const Text('Bước trước'),
            ),
        ],
      ),
    );
  }
}
