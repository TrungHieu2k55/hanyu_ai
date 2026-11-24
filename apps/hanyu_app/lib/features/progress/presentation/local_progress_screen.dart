import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/utils/vietnam_time.dart';
import 'package:doanchuyennganh2/features/progress/domain/local_learning_stats.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

import 'local_progress_summary.dart';

class LocalProgressScreen extends StatefulWidget {
  const LocalProgressScreen({required this.data, required this.now, super.key});
  final LocalSnapshot data;
  final DateTime now;
  @override
  State<LocalProgressScreen> createState() => _LocalProgressScreenState();
}

class _LocalProgressScreenState extends State<LocalProgressScreen> {
  String kind = 'Tất cả';
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final saved = data.words
        .where((w) => w.saved)
        .map((w) => w.entry.id)
        .toSet();
    final stats = localLearningStats(data.review.events, saved, widget.now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          'Tiến độ của bạn',
          'Hoạt động học đã lưu trên thiết bị này.',
        ),
        const SizedBox(height: 20),
        LocalProgressSummary(
          stats: stats,
          savedCount: saved.length,
          now: widget.now,
        ),
        const SizedBox(height: 18),
        Text(
          stats.selfRememberedRatio == null
              ? 'Chưa có dữ liệu tự đánh giá'
              : '${(stats.selfRememberedRatio! * 100).round()}% lượt tự đánh giá ở mức Khó / Nhớ / Dễ',
        ),
        Text(
          '${stats.currentlyRemembered} từ đang lưu có đánh giá gần nhất từ mức Khó trở lên.',
        ),
        const Text(
          'Đây là tự đánh giá, không đo mức thông thạo hoặc năng lực HSK.',
        ),
        const SizedBox(height: 24),
        buildSectionHeading('Lịch sử ôn và bài đọc'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in ['Tất cả', 'Ôn tập', 'Bài đọc'])
              ChoiceChip(
                label: Text(value),
                selected: kind == value,
                onSelected: (_) => setState(() => kind = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (data.review.sessions.isEmpty && data.exams.attempts.isEmpty)
          const Text('Chưa có phiên học được lưu.'),
        if (kind != 'Bài đọc')
          for (final session in data.review.sessions)
            buildActionTile(
              Icons.style_outlined,
              'Ôn tập · ${session.position}/${session.cards.length} thẻ',
              '${session.completed ? 'Đã hoàn thành' : 'Đang dở'} · ${formatVietnamTime(session.finishedAt ?? session.createdAt)}',
              () => context.push('/review/session/${session.id}'),
            ),
        if (kind != 'Ôn tập')
          for (final attempt in data.exams.attempts)
            buildActionTile(
              Icons.quiz_outlined,
              attempt.done
                  ? 'Bài đọc · ${attempt.correctCount}/${attempt.questions.length} câu'
                  : 'Bài đọc đang làm · ${attempt.answers.length}/${attempt.questions.length} đáp án lưu',
              '${attempt.timedOut
                  ? 'Hết giờ'
                  : attempt.done
                  ? 'Đã nộp'
                  : 'Đang làm'} · ${formatVietnamTime(attempt.submittedAt ?? attempt.startedAt)}',
              () => context.push('/exams/attempts/${attempt.id}'),
            ),
      ],
    );
  }
}
