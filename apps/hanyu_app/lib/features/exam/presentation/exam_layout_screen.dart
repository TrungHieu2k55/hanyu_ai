import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/exam/data/sample_questions.dart';
import 'package:doanchuyennganh2/features/exam/presentation/question_choices.dart';
import 'package:doanchuyennganh2/shared/widgets/audio_player_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

/// Full layout only. It does not create an attempt, run a timer or record marks.
class ExamLayoutScreen extends StatefulWidget {
  const ExamLayoutScreen({required this.level, super.key});
  final int level;
  @override
  State<ExamLayoutScreen> createState() => _ExamLayoutScreenState();
}

class _ExamLayoutScreenState extends State<ExamLayoutScreen> {
  int position = 0;
  final answers = <int, int>{};
  bool explanation = false;
  void go(int next) => setState(() {
    position = next;
    explanation = false;
  });
  @override
  Widget build(BuildContext context) {
    final listening = position < 10;
    final example = sampleQuestions[position % sampleQuestions.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Bố cục 20 câu · HSK ${widget.level}',
          '10 vị trí nghe + 10 vị trí đọc. Lặp lại ví dụ để kiểm tra UI; không phải đề được duyệt, không tạo attempt, chạy giờ hoặc tính điểm.',
        ),
        const SizedBox(height: 20),
        const Text(
          '--:-- · Chỉ xem bố cục',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final group in [
          (0, 'Phần nghe · câu 1–10'),
          (10, 'Phần đọc · câu 11–20'),
        ]) ...[
          Text(group.$2),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = group.$1; i < group.$1 + 10; i++)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text('${i + 1}${answers.containsKey(i) ? " ✓" : ""}'),
                  selected: position == i,
                  onSelected: (_) => go(i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Câu ${position + 1} / 20 · ${listening ? "Nghe" : "Đọc"}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (listening) ...[
          const AudioPlayerPanel(
            description: 'Chưa có audio. Câu hỏi và lựa chọn dưới đây chỉ minh họa bố cục; không đánh giá kỹ năng nghe.',
          ),
          const SizedBox(height: 16),
        ],
        PanelCard(
          child: Text(example.prompt, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 16),
        QuestionChoices(
          choices: example.choices,
          selected: answers[position],
          onSelected: (value) => setState(() => answers[position] = value),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: position == 0 ? null : () => go(position - 1),
              child: const Text('Vị trí trước'),
            ),
            FilledButton(
              onPressed: position == 19 ? null : () => go(position + 1),
              child: const Text('Vị trí tiếp'),
            ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => explanation = !explanation),
          child: const Text('Xem lời giải ví dụ'),
        ),
        if (explanation) Text(example.explanation),
        const SizedBox(height: 16),
        Text(
          'Đã thử chọn ${answers.length}/20 vị trí. Không lưu vào tiến độ hoặc điểm thi.',
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Về hướng dẫn đề'),
        ),
      ],
    );
  }
}
