import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

class LocalReviewSession {
  LocalReviewSession({
    required this.id,
    required List<VocabularyItem> cards,
    required this.position,
    required this.revealed,
    required this.createdAt,
    required this.finishedAt,
    required List<int> qualities,
  }) : cards = List.unmodifiable(cards),
       qualities = List.unmodifiable(qualities);
  final String id;
  final List<VocabularyItem> cards;
  final int position;
  final bool revealed;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<int> qualities;
  bool get completed => position >= cards.length;
}

class LocalReviewEvent {
  const LocalReviewEvent({
    required this.id,
    required this.wordId,
    required this.sessionId,
    required this.quality,
    required this.acceptedAt,
  });
  final String id, wordId, sessionId;
  final int quality;
  final DateTime acceptedAt;
}

class LocalReviewState {
  const LocalReviewState({
    this.sessions = const [],
    this.dueCount = 0,
    this.eventCount = 0,
    this.events = const [],
  });
  final List<LocalReviewSession> sessions;
  final int dueCount, eventCount;
  final List<LocalReviewEvent> events;
  LocalReviewSession? get active {
    for (final session in sessions) {
      if (!session.completed) return session;
    }
    return null;
  }

  LocalReviewSession? find(String id) {
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }
}
