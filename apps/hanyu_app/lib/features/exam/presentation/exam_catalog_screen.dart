import 'package:doanchuyennganh2/features/exam/data/sample_questions.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_instructions_screen.dart';
import 'package:doanchuyennganh2/features/exam/presentation/exam_runner_screen.dart';
import 'package:doanchuyennganh2/features/exam/presentation/listening_preview_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class ExamCatalogScreen extends StatefulWidget {
  const ExamCatalogScreen({
    super.key,
    required this.attempts,
    required this.onChanged,
  });
  final List<ExamAttempt> attempts;
  final VoidCallback onChanged;
  @override
  State<ExamCatalogScreen> createState() => _ExamCatalogScreenState();
}

class _ExamCatalogScreenState extends State<ExamCatalogScreen> {
  Future<void> open(ExamAttempt attempt) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: 'Mini-test · HSK ${attempt.level}',
          body: ExamRunnerScreen(attempt: attempt, onChanged: widget.onChanged),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Thi thử từng bước',
        'Ba cấu hình cấp độ. Hiện dùng chung 4 câu đọc tự biên soạn, chưa kiểm duyệt; chưa có audio hoặc bộ đề 20 câu.',
      ),
      const SizedBox(height: 24),
      for (final attempt in widget.attempts.where((a) => !a.done))
        buildActionTile(
          Icons.play_circle_outline,
          'Tiếp tục bài ${attempt.number} · HSK ${attempt.level}',
          '${attempt.answers.length}/4 câu đã chọn · đồng hồ vẫn chạy',
          () => open(attempt),
        ),
      TextButton.icon(
        onPressed: () => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => const DetailScaffold(
              title: 'Bài nghe · mẫu UI',
              body: ListeningPreviewScreen(),
            ),
          ),
        ),
        icon: const Icon(Icons.headphones_outlined),
        label: const Text('Xem giao diện bài nghe'),
      ),
      for (var level = 1; level <= 3; level++)
        buildActionTile(
          Icons.quiz_outlined,
          'Mini-test HSK $level',
          'Cấu hình mẫu · 4 câu đọc · 20 phút',
          () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScaffold(
                title: 'Hướng dẫn mini-test',
                body: ExamInstructionsScreen(
                  level: level,
                  onStart: () {
                    final attempt = ExamAttempt(
                      widget.attempts.length + 1,
                      level,
                      questions: sampleQuestions,
                    );
                    widget.attempts.add(attempt);
                    widget.onChanged();
                    Navigator.pop(context);
                    open(attempt);
                  },
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 24),
      buildSectionHeading('Lịch sử bài mẫu'),
      if (widget.attempts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Chưa có bài làm. Xem hướng dẫn trước khi bắt đầu.'),
        ),
      for (final attempt in widget.attempts.reversed)
        buildActionTile(
          attempt.done ? Icons.fact_check_outlined : Icons.pause_circle_outline,
          'Bài ${attempt.number} · HSK ${attempt.level}',
          attempt.done
              ? 'Đã khóa bài · đúng ${attempt.correct}/4 · ${attempt.timedOut ? "hết giờ" : "đã nộp"}'
              : 'Đang làm · ${attempt.answers.length}/4 câu đã chọn',
          () => open(attempt),
        ),
    ],
  );
}
