import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/detail_scaffold.dart';
import '../../../shared/widgets/handwriting_pad.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../../shared/widgets/unsaved_changes_guard.dart';
import '../../writing/data/writing_samples.dart';
import '../../writing/presentation/prediction_result_screen.dart';

class HandwritingLookupScreen extends StatefulWidget {
  const HandwritingLookupScreen({this.preview = false, super.key});

  final bool preview;

  @override
  State<HandwritingLookupScreen> createState() =>
      _HandwritingLookupScreenState();
}

class _HandwritingLookupScreenState extends State<HandwritingLookupScreen> {
  static const _maxStrokes = 500;
  static const _maxPoints = 20000;
  final strokes = <List<Offset>>[];
  final query = TextEditingController();
  bool opening = false, drawing = false;
  int points = 0;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void clear() => setState(() {
    strokes.clear();
    points = 0;
    drawing = false;
  });

  Future<void> showResult({bool noSuggestions = false}) async {
    if (!widget.preview || strokes.isEmpty || drawing || opening) return;
    setState(() => opening = true);
    final character = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: 'Nhận diện chữ · mẫu',
          body: PredictionResultScreen(
            mode: noSuggestions
                ? PredictionMode.noSuggestions
                : PredictionMode.candidates,
            strokes: [for (final line in strokes) List<Offset>.of(line)],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => opening = false);
    if (character == null) return;
    final item = {
      '人': ('rén', 'người', '他是越南人。'),
      '入': ('rù', 'vào, đi vào', '请入内。'),
      '八': ('bā', 'số tám', '现在八点。'),
    }[character];
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: 'Chi tiết chữ $character · mẫu',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildPageTitle(
                character,
                item == null
                    ? 'Chữ bạn chọn thủ công.'
                    : '${item.$1} · ${item.$2}',
              ),
              if (item != null)
                Text(item.$3, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  clear();
                  Navigator.of(context).pop();
                },
                child: const Text('Viết chữ khác'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void search() {
    final value = query.text.trim();
    if (value.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(
      Uri(path: '/learn/words', queryParameters: {'q': value}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: strokes.isNotEmpty,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (MediaQuery.sizeOf(context).width >= 760)
              Text(
                'Viết tay để tra chữ',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            Text(
              widget.preview
                  ? 'Mẫu nhận diện · Các gợi ý cố định chỉ để thử luồng.'
                  : 'Dùng ngón tay hoặc chuột để viết một chữ trong ô.',
            ),
            if (!widget.preview) ...[
              const SizedBox(height: 12),
              const Text('Nhận diện chữ viết tay chưa được kết nối.'),
              const SizedBox(height: 12),
              TextField(
                controller: query,
                textInputAction: TextInputAction.search,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Chữ muốn tra bằng bàn phím',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => search(),
              ),
              FilledButton(
                onPressed: query.text.trim().isEmpty ? null : search,
                child: const Text('Tra bằng bàn phím'),
              ),
            ],
            const SizedBox(height: 18),
            LearnerSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Viết một chữ vào ô'),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Ô viết chữ Hán',
                    child: HandwritingPad(
                      key: const ValueKey('handwriting-lookup-pad'),
                      strokes: strokes,
                      enabled: !opening,
                      onStart: (point) {
                        if (strokes.length >= _maxStrokes ||
                            points >= _maxPoints) {
                          return;
                        }
                        setState(() {
                          drawing = true;
                          strokes.add([point]);
                          points++;
                        });
                      },
                      onUpdate: (point) {
                        if (!drawing || points >= _maxPoints) return;
                        setState(() {
                          strokes.last.add(point);
                          points++;
                        });
                      },
                      onEnd: () => setState(() => drawing = false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: strokes.isEmpty || drawing
                      ? null
                      : () => setState(
                          () => points -= strokes.removeLast().length,
                        ),
                  icon: const Icon(Icons.undo),
                  label: const Text('Hoàn tác'),
                ),
                OutlinedButton.icon(
                  onPressed: strokes.isEmpty || drawing ? null : clear,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Xóa bảng'),
                ),
              ],
            ),
            if (strokes.length >= _maxStrokes || points >= _maxPoints)
              const Text('Ô viết đã đầy. Hoàn tác hoặc xóa bảng để tiếp tục.'),
            const SizedBox(height: 14),
            if (widget.preview) ...[
              FilledButton(
                onPressed: strokes.isNotEmpty && !drawing && !opening
                    ? showResult
                    : null,
                child: const Text('Nhận diện chữ'),
              ),
              TextButton(
                onPressed: strokes.isEmpty || drawing || opening
                    ? null
                    : () => showResult(noSuggestions: true),
                child: const Text('Xem mẫu khi không có gợi ý'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => context.push('/preview/handwriting'),
                child: const Text('Xem mẫu nhận diện chữ'),
              ),
              TextButton(
                onPressed: () => context.push('/writing'),
                child: const Text('Lịch sử luyện viết'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class LocalStrokePicker extends StatelessWidget {
  const LocalStrokePicker({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Chọn chữ để luyện',
        'Chọn chữ có nét mẫu để xem và tập theo.',
      ),
      const SizedBox(height: 16),
      for (final (hanzi, pinyin, meaning) in writingSamples)
        buildActionTile(
          Icons.draw_outlined,
          '$hanzi · $pinyin',
          hanzi == '人'
              ? '$meaning · Có hai nét minh họa'
              : '$meaning · Chưa có dữ liệu nét',
          () => context.push('/practice/strokes/${Uri.encodeComponent(hanzi)}'),
        ),
      TextButton(
        onPressed: () => context.push('/practice/handwriting'),
        child: const Text('Chuyển sang viết tự do'),
      ),
    ],
  );
}
