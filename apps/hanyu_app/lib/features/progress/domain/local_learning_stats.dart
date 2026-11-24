import 'package:doanchuyennganh2/features/review/domain/local_review.dart';

int vietnamDay(DateTime time) {
  final value = time.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(
        value.year,
        value.month,
        value.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

class LocalLearningStats {
  const LocalLearningStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.savedLearned,
    required this.currentlyRemembered,
    required this.reviewCount,
    required this.selfRememberedRatio,
    required this.dailyCounts,
  });
  final int currentStreak,
      longestStreak,
      savedLearned,
      currentlyRemembered,
      reviewCount;
  final double? selfRememberedRatio;
  final Map<int, int> dailyCounts;
}

LocalLearningStats localLearningStats(
  List<LocalReviewEvent> events,
  Set<String> savedIds,
  DateTime now,
) {
  final ordered = [...events]
    ..sort((a, b) => a.acceptedAt.compareTo(b.acceptedAt));
  final latest = <String, int>{}, days = <int, int>{};
  for (final event in ordered) {
    latest[event.wordId] = event.quality;
    final day = vietnamDay(event.acceptedAt);
    days.update(day, (n) => n + 1, ifAbsent: () => 1);
  }
  final today = vietnamDay(now), activeDays = days.keys.toList()..sort();
  var current = 0, cursor = days.containsKey(today) ? today : today - 1;
  while (days.containsKey(cursor)) {
    current++;
    cursor--;
  }
  var longest = 0, run = 0;
  int? previous;
  for (final day in activeDays) {
    run = previous != null && day == previous + 1 ? run + 1 : 1;
    if (run > longest) longest = run;
    previous = day;
  }
  return LocalLearningStats(
    currentStreak: current,
    longestStreak: longest,
    savedLearned: savedIds.where(latest.containsKey).length,
    currentlyRemembered: savedIds.where((id) => (latest[id] ?? -1) >= 3).length,
    reviewCount: events.length,
    selfRememberedRatio: events.isEmpty
        ? null
        : events.where((e) => e.quality >= 3).length / events.length,
    dailyCounts: Map.unmodifiable(days),
  );
}
