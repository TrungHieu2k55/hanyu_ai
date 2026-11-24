import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../../shared/widgets/presentation_helpers.dart';

class LocalPracticeHome extends StatelessWidget {
  const LocalPracticeHome({super.key});

  static const modes = [
    (
      FigmaGlyph.practice,
      'Luyện viết có lưu',
      'Lưu nét bút và xem lại lịch sử',
      '/writing',
    ),
    (
      FigmaGlyph.camera,
      'Ảnh và văn bản tự nhập',
      'Chụp hoặc chọn ảnh rồi tra từ',
      '/photos',
    ),
    (
      FigmaGlyph.conversation,
      'Hội thoại thủ công và audio',
      'Tập nói, ghi âm và nghe lại',
      '/conversations',
    ),
    (
      FigmaGlyph.headphones,
      'Thi thử và luyện đọc',
      'Làm bài và xem kết quả đã lưu',
      '/exams',
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle('Luyện tập', 'Chọn bài luyện cho hôm nay.'),
      const SizedBox(height: 20),
      const Text(
        'BẮT ĐẦU TỪ NÉT CHỮ',
        style: TextStyle(
          color: brandTeal,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: .7,
        ),
      ),
      const SizedBox(height: 10),
      LearnerSurface(
        padding: EdgeInsets.zero,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < modes.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: surfaceBorder),
                ListTile(
                  tileColor: i == 0 ? softSurface : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: FigmaIcon(modes[i].$1),
                  title: Text(
                    modes[i].$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(modes[i].$3),
                  trailing: const Icon(Icons.arrow_forward, size: 18),
                  onTap: () => context.push(modes[i].$4),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      const LearnerSurface(
        child: Text('Từ đã lưu có thể ôn lại ở tab Ôn tập.'),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.push('/preview'),
        child: const Text('Xem các luồng thực hành mẫu'),
      ),
    ],
  );
}
