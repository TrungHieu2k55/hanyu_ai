import 'package:doanchuyennganh2/features/writing/presentation/stroke_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/data/writing_samples.dart';
import 'package:doanchuyennganh2/features/writing/presentation/writing_canvas_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class WritingPickerScreen extends StatelessWidget {
  const WritingPickerScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Chọn chữ để luyện',
        '5 chữ minh họa giao diện. Chưa phải danh sách 50 nhãn CNN được kiểm chứng.',
      ),
      const SizedBox(height: 24),
      for (final word in writingSamples)
        buildActionTile(
          Icons.draw_outlined,
          '${word.$1} · ${word.$2}',
          word.$3,
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScaffold(
                title: 'Chế độ luyện viết',
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildPageTitle('${word.$1} · ${word.$2}', word.$3),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScaffold(
                            title: 'Viết tự do',
                            body: WritingCanvasScreen(
                              hanzi: word.$1,
                              pinyin: word.$2,
                              meaning: word.$3,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Viết tự do trên canvas'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailScaffold(
                            title: 'Hướng dẫn thứ tự nét',
                            body: StrokeGuideScreen(
                              hanzi: word.$1,
                              pinyin: word.$2,
                              meaning: word.$3,
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Hướng dẫn và quiz theo nét'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Theo nét và tự do là hai chế độ khác nhau. Canvas tự do chưa kiểm tra thứ tự nét hoặc dự đoán bằng CNN.',
                      style: TextStyle(color: mutedText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
