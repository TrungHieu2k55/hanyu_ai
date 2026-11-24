import 'package:doanchuyennganh2/shared/widgets/handwriting_pad.dart';
import 'package:doanchuyennganh2/features/writing/presentation/character_picker.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/presentation/prediction_result_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/widgets/unsaved_changes_guard.dart';

class WritingCanvasScreen extends StatefulWidget {
  const WritingCanvasScreen({
    super.key,
    this.hanzi = '人',
    this.pinyin = 'rén',
    this.meaning = 'người',
  });
  final String hanzi, pinyin, meaning;
  @override
  State<WritingCanvasScreen> createState() => _WritingCanvasScreenState();
}

class _WritingCanvasScreenState extends State<WritingCanvasScreen> {
  final strokes = <List<Offset>>[];
  String? manualChoice;
  bool openingPrediction = false;
  @override
  Widget build(BuildContext context) => UnsavedChangesGuard(
    dirty: strokes.isNotEmpty,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPageTitle(
          '${widget.hanzi} · ${widget.pinyin} · ${widget.meaning}',
          'Thử nét bút trên ô vuông. Chưa chấm thứ tự nét hoặc nhận diện CNN.',
        ),
        const SizedBox(height: 24),
        HandwritingPad(
          key: const ValueKey('writing-canvas'),
          strokes: strokes,
          onStart: (point) => setState(() {
            manualChoice = null;
            strokes.add([point]);
          }),
          onUpdate: (point) => setState(() => strokes.last.add(point)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: strokes.isEmpty
                  ? null
                  : () => setState(() => strokes.removeLast()),
              icon: const Icon(Icons.undo),
              label: const Text('Hoàn tác'),
            ),
            OutlinedButton.icon(
              onPressed: strokes.isEmpty
                  ? null
                  : () => setState(() {
                      strokes.clear();
                      manualChoice = null;
                    }),
              icon: const Icon(Icons.refresh),
              label: const Text('Viết lại'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: strokes.isEmpty || openingPrediction
              ? null
              : () async {
                  if (openingPrediction) return;
                  setState(() => openingPrediction = true);
                  final result = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailScaffold(
                        title: 'Nhận diện chữ',
                        body: PredictionResultScreen(
                          strokes: strokes
                              .map((line) => List<Offset>.of(line))
                              .toList(),
                        ),
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      openingPrediction = false;
                      if (result != null) manualChoice = result;
                    });
                  }
                },
          icon: const Icon(Icons.search),
          label: const Text('Nhận diện chữ'),
        ),
        TextButton(
          onPressed: () async {
            final choice = await showCharacterPicker(context);
            if (choice != null && mounted) {
              setState(() => manualChoice = choice);
            }
          },
          child: const Text('Chọn chữ thủ công'),
        ),
        if (manualChoice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Bạn chọn thủ công: $manualChoice · Không phải dự đoán CNN.',
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Dùng ngón tay hoặc chuột để viết. Cuộn ngoài ô để di chuyển trang. Chưa có model nên bản mẫu không đưa ra điểm số.',
        ),
      ],
    ),
  );
}
