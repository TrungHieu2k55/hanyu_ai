import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class LocalExamResult extends StatefulWidget {
  const LocalExamResult({required this.attempt, super.key});
  final LocalExamAttempt attempt;
  @override
  State<LocalExamResult> createState() => _LocalExamResultState();
}

class _LocalExamResultState extends State<LocalExamResult> {
  String filter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    // Submitting from the bottom of a long question must reveal the result.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    bool visible(int index) {
      final chosen = attempt.answers[index];
      return filter == 'Tất cả' ||
          (filter == 'Đúng' && chosen == attempt.questions[index].correct) ||
          (filter == 'Sai' &&
              chosen != null &&
              chosen != attempt.questions[index].correct) ||
          (filter == 'Bỏ trống' && chosen == null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Kết quả luyện đọc',
          attempt.timedOut
              ? 'Bài đã khóa do hết giờ. Chỉ chấm đáp án đã lưu.'
              : 'Bài đã nộp và khóa đáp án.',
        ),
        const SizedBox(height: 24),
        Text(
          '${attempt.correctCount} / ${attempt.questions.length}',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: brandTeal,
          ),
        ),
        Text(
          '${attempt.answers.length} câu đã chọn · ${attempt.blanks} câu bỏ trống',
        ),
        const SizedBox(height: 12),
        const Text(
          'Nội dung và đáp án còn là bản nháp chưa kiểm duyệt. Đây không phải đánh giá năng lực HSK hoặc kết quả bài nghe.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ['Tất cả', 'Đúng', 'Sai', 'Bỏ trống'])
              ChoiceChip(
                label: Text(value),
                selected: filter == value,
                onSelected: (_) => setState(() => filter = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < attempt.questions.length; i++)
          if (visible(i))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Câu ${i + 1} · ${attempt.answers[i] == null
                        ? 'Bỏ trống'
                        : attempt.answers[i] == attempt.questions[i].correct
                        ? 'Đúng'
                        : 'Sai'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    attempt.questions[i].prompt,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn chọn: ${attempt.answers[i] == null ? 'Chưa có đáp án đã lưu' : attempt.questions[i].choices[attempt.answers[i]!]}',
                  ),
                  Text(
                    'Đáp án nháp: ${attempt.questions[i].choices[attempt.questions[i].correct]}',
                  ),
                  const SizedBox(height: 8),
                  Text(attempt.questions[i].explanation),
                  const Divider(),
                ],
              ),
            ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/exams'),
          child: const Text('Về danh sách bài luyện'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () =>
              context.push('/exams/packages/${attempt.packageId}/instructions'),
          child: const Text('Làm lại bằng bài mới'),
        ),
      ],
    );
  }
}
