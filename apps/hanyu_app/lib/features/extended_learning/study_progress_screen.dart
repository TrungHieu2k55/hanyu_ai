import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/local/local_models.dart';
import '../../core/utils/vietnam_time.dart';
import '../../shared/ui_tokens.dart';
import '../../shared/widgets/learner_surface.dart';
import '../../shared/widgets/presentation_helpers.dart';
import '../../shared/widgets/status_panel.dart';
import '../progress/domain/local_learning_stats.dart';
import 'study_lesson.dart';
import 'study_tools_widgets.dart';

class StudyGoalsScreen extends StatelessWidget {
  const StudyGoalsScreen({
    required this.snapshot,
    required this.now,
    super.key,
  });
  final LocalSnapshot snapshot;
  final DateTime now;

  @override
  Widget build(BuildContext context) => StudyDataView(
    builder: (data) {
      final today = vietnamDay(now);
      final reviews = snapshot.review.events;
      final reviewsToday = reviews
          .where((row) => vietnamDay(row.acceptedAt) == today)
          .length;
      final solved = data.attempts.where((a) => a.correct);
      final lessonsToday = solved
          .where((row) => vietnamDay(row.at) == today)
          .map((a) => a.lessonId)
          .toSet()
          .length;
      final total = reviewsToday + lessonsToday;
      const target = 5;
      final badges = [
        ('Lượt ôn đầu tiên', reviews.length, 1),
        ('Ôn đủ 10 lượt', reviews.length, 10),
        (
          'Giải đúng 3 bài khác nhau',
          solved.map((a) => a.lessonId).toSet().length,
          3,
        ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Thử thách & huy hiệu',
            'Tiến độ trên thiết bị · tính theo ngày Việt Nam.',
          ),
          const SizedBox(height: 20),
          LearnerSplit(
            main: LearnerSurface(
              color: softSurface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mục tiêu hôm nay',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$total / $target hoạt động',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (total / target).clamp(0, 1).toDouble(),
                    semanticsLabel: 'Tiến độ thử thách',
                  ),
                  const SizedBox(height: 12),
                  Text('$reviewsToday lượt ôn · $lessonsToday bài luyện đúng'),
                  if (total >= target)
                    const Text('Đã hoàn thành thử thách hôm nay.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/practice/lessons'),
                    child: const Text('Chọn bài luyện'),
                  ),
                ],
              ),
            ),
            aside: LearnerSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildSectionHeading('Huy hiệu'),
                  for (final (name, count, goal) in badges)
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          count >= goal
                              ? Icons.emoji_events_outlined
                              : Icons.lock_outline,
                          color: count >= goal ? streakInk : mutedText,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          count >= goal ? 'Đã mở' : '$count / $goal · Chưa mở',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

enum _MistakeKind {
  lesson('Bài luyện'),
  review('Ôn tập'),
  exam('Thi thử');

  const _MistakeKind(this.label);
  final String label;
}

class StudyMistakesScreen extends StatefulWidget {
  const StudyMistakesScreen({required this.snapshot, super.key});
  final LocalSnapshot snapshot;

  @override
  State<StudyMistakesScreen> createState() => _StudyMistakesScreenState();
}

class _StudyMistakesScreenState extends State<StudyMistakesScreen> {
  _MistakeKind? filter;

  @override
  Widget build(BuildContext context) => StudyDataView(
    builder: (data) {
      final snapshot = widget.snapshot;
      final rows = <(_MistakeKind, String, DateTime, String)>[
        for (final a in data.attempts.where((row) => !row.correct))
          if (studyLessons
                  .where((lesson) => lesson.id == a.lessonId)
                  .firstOrNull
              case final lesson?)
            (
              _MistakeKind.lesson,
              lesson.title,
              a.at,
              '/practice/lessons/${a.lessonId}',
            ),
        for (final e in snapshot.review.events.where((row) => row.quality == 0))
          if (snapshot.find(e.wordId) case final word?)
            (
              _MistakeKind.review,
              '${word.entry.hanzi} · ${word.entry.vietnamese}',
              e.acceptedAt,
              '/words/${Uri.encodeComponent(e.wordId)}',
            ),
        for (final attempt in snapshot.exams.attempts)
          if (attempt.submittedAt case final submitted?)
            for (final answer in attempt.answers.entries)
              if (answer.value != attempt.questions[answer.key].correct)
                (
                  _MistakeKind.exam,
                  attempt.questions[answer.key].prompt,
                  submitted,
                  '/exams/attempts/${attempt.id}',
                ),
      ]..sort((a, b) => b.$3.compareTo(a.$3));
      final display = rows
          .where((row) => filter == null || row.$1 == filter)
          .take(100);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Sổ lỗi cá nhân',
            'Xem lại bài luyện sai, thẻ đã quên và câu thi trả lời sai.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in <_MistakeKind?>[
                null,
                ..._MistakeKind.values,
              ])
                ChoiceChip(
                  label: Text(option?.label ?? 'Tất cả'),
                  selected: filter == option,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (_) => setState(() => filter = option),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (display.isEmpty)
            const StatusPanel(
              icon: Icons.fact_check_outlined,
              title: 'Chưa có lỗi trong mục này',
              message:
                  'Các câu trả lời đã lưu sẽ xuất hiện ở đây khi cần xem lại.',
            )
          else
            for (final (kind, title, at, path) in display) ...[
              buildActionTile(
                Icons.replay_outlined,
                title,
                '${kind.label} · ${formatVietnamTime(at)}',
                () => context.push(path),
              ),
              const Divider(height: 1),
            ],
        ],
      );
    },
  );
}
