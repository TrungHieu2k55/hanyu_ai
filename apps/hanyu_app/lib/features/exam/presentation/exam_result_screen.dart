import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({super.key, required this.attempt});
  final ExamAttempt attempt;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        attempt.timedOut ? 'Hết giờ · bài đã khóa' : 'Kết quả bài mẫu',
        'Đúng ${attempt.correct}/4 · sai ${attempt.answers.length - attempt.correct} · bỏ trống ${attempt.blanks}',
      ),
      const SizedBox(height: 16),
      const Text(
        'Đây không phải điểm HSK chính thức. Bài đã khóa, muốn làm lại hãy bắt đầu bài mới.',
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Câu ${i + 1} · ${!attempt.answers.containsKey(i)
                      ? "Bỏ trống"
                      : attempt.answers[i] == attempt.questions[i].correct
                      ? "Đúng"
                      : "Sai"}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(attempt.questions[i].prompt),
                Text(
                  'Bạn chọn: ${attempt.answers.containsKey(i) ? attempt.questions[i].choices[attempt.answers[i]!] : "Chưa chọn"}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Đáp án: ${attempt.questions[i].choices[attempt.questions[i].correct]}',
                  style: const TextStyle(color: brandTeal),
                ),
                Text(attempt.questions[i].explanation),
              ],
            ),
          ),
        ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Về danh sách đề'),
      ),
    ],
  );
}
