import 'package:doanchuyennganh2/features/writing/presentation/stroke_illustration_painter.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/presentation/stroke_practice_screen.dart';
import 'package:doanchuyennganh2/features/writing/presentation/writing_canvas_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/handwriting_pad.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';

class StrokeGuideScreen extends StatefulWidget {
  const StrokeGuideScreen({
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
    super.key,
  });
  final String hanzi, pinyin, meaning;
  @override
  State<StrokeGuideScreen> createState() => _StrokeGuideScreenState();
}

class _StrokeGuideScreenState extends State<StrokeGuideScreen>
    with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  int current = 0;
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  void play() {
    if (animation.isAnimating) {
      setState(animation.stop);
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => animation.value = 1);
      return;
    }
    setState(() {
      if (animation.value == 1) animation.value = 0;
      animation.forward();
    });
  }

  void go(int step) {
    animation.stop();
    setState(() {
      current = step;
      animation.value = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hanzi != '人') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle('${widget.hanzi} · ${widget.pinyin}', widget.meaning),
          const SizedBox(height: 20),
          const PreviewStatusPanel(
            state: PreviewState.notConfigured,
            message: 'Chưa có dữ liệu thứ tự nét cho chữ này. Không tự suy ra nét hoặc điểm số.',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  title: 'Viết tự do',
                  body: WritingCanvasScreen(
                    hanzi: widget.hanzi,
                    pinyin: widget.pinyin,
                    meaning: widget.meaning,
                  ),
                ),
              ),
            ),
            child: const Text('Dùng canvas tự do'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          '人 · hai nét minh họa',
          'Nét do ứng dụng tự dựng để xem UI. Chưa nạp dữ liệu Hanzi Writer hoặc kiểm tra viết đúng.',
        ),
        const SizedBox(height: 20),
        AnimatedBuilder(
          animation: animation,
          builder: (_, _) => Column(
            children: [
              HandwritingPad(
                strokes: const [],
                enabled: false,
                onStart: (_) {},
                onUpdate: (_) {},
                overlay: StrokeIllustrationPainter(
                  active: current,
                  progress: animation.value,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nét ${current + 1} / 2 · ${current == 0 ? "phẩy sang trái" : "mác sang phải"}',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: play,
                icon: Icon(
                  animation.isAnimating ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(
                  animation.isAnimating ? 'Tạm dừng nét mẫu' : 'Phát nét mẫu',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: current == 0 ? null : () => go(0),
              child: const Text('Nét trước'),
            ),
            OutlinedButton(
              onPressed: current == 1 ? null : () => go(1),
              child: const Text('Nét tiếp'),
            ),
            TextButton(
              onPressed: () => go(0),
              child: const Text('Xem lại từ đầu'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => const DetailScaffold(
                title: 'Tập theo nét · mẫu',
                body: StrokePracticeScreen(),
              ),
            ),
          ),
          child: const Text('Thử luyện theo hai nét mẫu'),
        ),
      ],
    );
  }
}
