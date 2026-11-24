import 'package:doanchuyennganh2/features/exam/presentation/question_choices.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_result_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ExamRunnerScreen extends StatefulWidget {
  const ExamRunnerScreen({
    super.key,
    required this.attempt,
    required this.onChanged,
  });
  final ExamAttempt attempt;
  final VoidCallback onChanged;
  @override
  State<ExamRunnerScreen> createState() => _ExamRunnerScreenState();
}

class _ExamRunnerScreenState extends State<ExamRunnerScreen> {
  Timer? timer;
  bool asking = false;
  int get seconds => widget.attempt.remainingSeconds;
  @override
  void initState() {
    super.initState();
    if (!widget.attempt.done && seconds == 0) {
      widget.attempt.finish(timeout: true);
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || widget.attempt.done) {
        timer?.cancel();
        return;
      }
      setState(() {
        if (seconds == 0) widget.attempt.finish(timeout: true);
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (asking || widget.attempt.done) return;
    asking = true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nộp bài mẫu?'),
        content: Text(
          'Còn ${widget.attempt.blanks} câu chưa chọn. Sau khi nộp không thể sửa đáp án của bài này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Tiếp tục làm'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Nộp và xem kết quả'),
          ),
        ],
      ),
    );
    asking = false;
    if (yes == true && mounted) {
      setState(() => widget.attempt.finish(timeout: seconds == 0));
      timer?.cancel();
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    if (attempt.done) return ExamResultScreen(attempt: attempt);
    final question = attempt.questions[attempt.index];
    final remaining = seconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Câu ${attempt.index + 1} / 4',
          'Còn ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, "0")} · Bài mẫu ${attempt.number}',
        ),
        const SizedBox(height: 16),
        const Text(
          'Đáp án được giữ tạm trong bộ nhớ, chưa đồng bộ. Có thể rời màn và tiếp tục trong lần mở app này.',
          style: TextStyle(color: mutedText, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 4; i++)
              ChoiceChip(
                showCheckmark: false,
                label: Text(
                  'Câu ${i + 1}${attempt.answers.containsKey(i) ? " ✓" : ""}',
                ),
                selected: attempt.index == i,
                onSelected: (_) => setState(() => attempt.index = i),
              ),
          ],
        ),
        const SizedBox(height: 24),
        PanelCard(
          child: Text(question.prompt, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(height: 20),
        QuestionChoices(
          choices: question.choices,
          selected: attempt.answers[attempt.index],
          onSelected: (choice) {
            setState(() => attempt.selectAnswer(attempt.index, choice));
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: attempt.index == 0
                  ? null
                  : () => setState(() => attempt.index--),
              child: const Text('Câu trước'),
            ),
            FilledButton(
              onPressed: attempt.index == 3
                  ? null
                  : () => setState(() => attempt.index++),
              child: const Text('Câu tiếp'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        OutlinedButton(onPressed: submit, child: const Text('Nộp bài mẫu')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Rời và giữ bài tạm'),
        ),
      ],
    );
  }
}
