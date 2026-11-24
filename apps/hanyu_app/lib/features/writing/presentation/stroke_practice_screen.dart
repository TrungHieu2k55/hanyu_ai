import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/presentation/stroke_illustration_painter.dart';
import 'package:doanchuyennganh2/shared/widgets/handwriting_pad.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class StrokePracticeScreen extends StatefulWidget {
  const StrokePracticeScreen({super.key});
  @override
  State<StrokePracticeScreen> createState() => _StrokePracticeScreenState();
}

class _StrokePracticeScreenState extends State<StrokePracticeScreen> {
  final strokes = <List<Offset>>[];
  int confirmed = 0, hints = 0;
  bool showHint = false;
  @override
  Widget build(BuildContext context) {
    if (confirmed == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Đã thử hai nét mẫu',
            'Bạn tự xác nhận 2/2 bước, dùng $hints lần gợi ý. Chưa chấm đúng/sai, điểm nét hoặc ghi attempt thật.',
          ),
          const SizedBox(height: 24),
          const PanelCard(
            child: Text(
              'Màn kết quả này chỉ mô tả lượt tập thủ công. Việc xác nhận không chứng minh chữ đã viết đúng hoặc đã được AI đánh giá.',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => setState(() {
              confirmed = 0;
              hints = 0;
              showHint = false;
              strokes.clear();
            }),
            child: const Text('Tập lại hai nét mẫu'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Về hướng dẫn nét'),
          ),
        ],
      );
    }
    return UnsavedChangesGuard(
      dirty: strokes.isNotEmpty || confirmed > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Tập nét ${confirmed + 1} / 2',
            'Vẽ rồi tự xác nhận bước đang tập. Chưa có bộ kiểm tra thứ tự nét.',
          ),
          const SizedBox(height: 20),
          HandwritingPad(
            key: const ValueKey('guided-writing-canvas'),
            strokes: strokes,
            onStart: (p) => setState(() => strokes.add([p])),
            onUpdate: (p) => setState(() => strokes.last.add(p)),
            overlay: showHint
                ? StrokeIllustrationPainter(active: confirmed, faint: true)
                : null,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: strokes.isEmpty
                ? null
                : () => setState(() {
                    confirmed++;
                    strokes.clear();
                    showHint = false;
                  }),
            child: Text('Tự xác nhận nét ${confirmed + 1}'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  hints++;
                  showHint = true;
                }),
                child: const Text('Gợi ý nét hiện tại'),
              ),
              TextButton(
                onPressed: strokes.isEmpty
                    ? null
                    : () => setState(strokes.clear),
                child: const Text('Vẽ lại nét này'),
              ),
            ],
          ),
          Text('Đã tự xác nhận $confirmed/2 bước · $hints lần gợi ý.'),
        ],
      ),
    );
  }
}
