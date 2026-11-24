import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../domain/local_learning_stats.dart';

class LocalProgressSummary extends StatelessWidget {
  const LocalProgressSummary({
    required this.stats,
    required this.savedCount,
    required this.now,
    super.key,
  });
  final LocalLearningStats stats;
  final int savedCount;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final today = vietnamDay(now);
    final days = [for (var offset = 6; offset >= 0; offset--) today - offset];
    final counts = [for (final day in days) stats.dailyCounts[day] ?? 0];
    final maxCount = counts.fold(1, (best, n) => n > best ? n : best);
    final weekCount = counts.fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (MediaQuery.sizeOf(context).width < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) ...[
          _Metric(value: stats.savedLearned, label: 'Từ đã học', primary: true),
          const SizedBox(height: 12),
          _Metric(value: savedCount, label: 'Từ đã lưu'),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _Metric(
                  value: stats.savedLearned,
                  label: 'Từ đã học',
                  primary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _Metric(value: savedCount, label: 'Từ đã lưu'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: StudyStreak(stats.currentStreak),
        ),
        const SizedBox(height: 12),
        LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Hoạt động tuần này',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '$weekCount lượt ôn',
                    style: const TextStyle(color: mutedText),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: _DayBar(
                        day: days[i],
                        count: counts[i],
                        maxCount: maxCount,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: softSurface,
                borderRadius: BorderRadius.circular(14),
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_stories_outlined,
                    color: brandTeal,
                  ),
                  title: const Text(
                    'Tiếp tục ôn hôm nay',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Xem thẻ còn đến hạn'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => context.go('/review'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '“Đã học” là từ đang lưu có ít nhất một lượt ôn. Chuỗi ngày chỉ tăng khi lưu lượt ôn.',
          style: TextStyle(color: mutedText, fontSize: 14),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.primary = false,
  });
  final int value;
  final String label;
  final bool primary;
  @override
  Widget build(BuildContext context) => LearnerSurface(
    color: primary ? brandInk : Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : brandInk,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: primary ? softSurface : mutedText,
          ),
        ),
      ],
    ),
  );
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.day,
    required this.count,
    required this.maxCount,
  });
  final int day, count, maxCount;
  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      day * Duration.millisecondsPerDay,
      isUtc: true,
    );
    final label = date.weekday == DateTime.sunday
        ? 'CN'
        : 'T${date.weekday + 1}';
    return Semantics(
      label: '$label: $count lượt ôn',
      excludeSemantics: true,
      child: Tooltip(
        message: '$label: $count lượt ôn',
        child: Column(
          children: [
            Container(
              width: 20,
              height: count == 0 ? 4 : 8 + 52 * count / maxCount,
              decoration: BoxDecoration(
                color: count == 0 ? surfaceBorder : brandTeal,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: mutedText)),
          ],
        ),
      ),
    );
  }
}
