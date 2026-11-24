import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/features/progress/domain/local_learning_stats.dart';
import 'package:doanchuyennganh2/features/review/domain/local_review.dart';

LocalReviewEvent event(String id, String word, int q, DateTime time) =>
    LocalReviewEvent(
      id: id,
      wordId: word,
      sessionId: 's-$id',
      quality: q,
      acceptedAt: time,
    );
void main() {
  test('empty history has no invented percentage or streak', () {
    final s = localLearningStats([], {'saved'}, DateTime.utc(2026, 11, 19));
    expect(s.selfRememberedRatio, isNull);
    expect(s.currentStreak, 0);
    expect(s.savedLearned, 0);
  });
  test('Vietnam midnight divides days and duplicate activity does not extend streak', () {
    final events = [
      event('a', 'w', 4, DateTime.utc(2026, 11, 18, 16, 59)),
      event('b', 'w', 0, DateTime.utc(2026, 11, 18, 17, 1)),
      event('c', 'x', 5, DateTime.utc(2026, 11, 19, 1)),
    ];
    final s = localLearningStats(events, {
      'w',
      'x',
    }, DateTime.utc(2026, 11, 19, 2));
    expect(s.currentStreak, 2);
    expect(s.longestStreak, 2);
    expect(s.dailyCounts.length, 2);
    expect(s.savedLearned, 2);
    expect(s.currentlyRemembered, 1);
    expect(s.reviewCount, 3);
  });
  test('yesterday keeps streak until the full next day is missed', () {
    final events = [
      event('a', 'w', 3, DateTime.utc(2026, 11, 17)),
      event('b', 'w', 4, DateTime.utc(2026, 11, 18)),
    ];
    expect(
      localLearningStats(events, {
        'w',
      }, DateTime.utc(2026, 11, 19)).currentStreak,
      2,
    );
    expect(
      localLearningStats(events, {
        'w',
      }, DateTime.utc(2026, 11, 20)).currentStreak,
      0,
    );
  });
  test(
    'learned in saved list excludes removed words and uses latest self-rating',
    () {
      final events = [
        event('a', 'w', 5, DateTime.utc(2026, 11, 17)),
        event('b', 'w', 0, DateTime.utc(2026, 11, 18)),
        event('c', 'removed', 4, DateTime.utc(2026, 11, 19)),
      ];
      final s = localLearningStats(events, {'w'}, DateTime.utc(2026, 11, 19));
      expect(s.savedLearned, 1);
      expect(s.currentlyRemembered, 0);
      expect(s.selfRememberedRatio, closeTo(2 / 3, 0.00001));
    },
  );
}
