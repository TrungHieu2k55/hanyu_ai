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
      'Luyện theo nét',
      'Chọn chữ mẫu rồi luyện thứ tự nét',
      '/practice/strokes',
    ),
    (
      FigmaGlyph.practice,
      'Viết tay để tra chữ',
      'Viết trực tiếp một chữ trong ô',
      '/practice/handwriting',
    ),
    (
      FigmaGlyph.camera,
      'Chụp ảnh để tra chữ',
      'Chụp hoặc chọn ảnh rồi tra từ',
      '/photos/new',
    ),
    (
      FigmaGlyph.conversation,
      'Hội thoại',
      'Tập nói, ghi âm và nghe lại',
      '/conversations',
    ),
    (
      FigmaGlyph.headphones,
      'Thi thử',
      'Làm bài và xem kết quả đã lưu',
      '/exams',
    ),
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (MediaQuery.sizeOf(context).width >= 760)
        buildPageTitle('Luyện tập', 'Chọn bài luyện cho hôm nay.')
      else
        Text(
          'Chọn bài luyện cho hôm nay.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      const SizedBox(height: 16),
      const Text(
        'LUYỆN VIẾT VÀ TRA CHỮ',
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
                  minTileHeight: 64,
                  tileColor: i == 0 ? softSurface : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: softSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: FigmaIcon(modes[i].$1, color: brandTeal),
                    ),
                  ),
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
        color: softSurface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FigmaIcon(FigmaGlyph.review, color: brandTeal),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Từ vựng dùng chung',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('Từ bạn lưu cũng xuất hiện trong bộ ôn.'),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.push('/practice/lessons'),
        child: const Text('Mở danh mục bài luyện'),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => context.push('/preview'),
        child: const Text('Xem các luồng thực hành mẫu'),
      ),
    ],
  );
}
