import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/exam/domain/exam_attempt.dart';
import 'package:doanchuyennganh2/features/ocr/domain/scan_record.dart';
import 'package:doanchuyennganh2/features/review/domain/review_session.dart';
import 'package:doanchuyennganh2/features/roleplay/domain/chat_session.dart';
import 'package:doanchuyennganh2/features/settings/domain/learning_preferences.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

class PreviewSessionStore {
  final saved = <String>{};
  final notes = <String, String>{};
  final personalWords = <VocabularyItem>[];
  int personalCounter = 0;
  final scanHistory = <ScanRecord>[];
  final chatSessions = <ChatSession>[];
  final examAttempts = <ExamAttempt>[];
  final preferences = LearningPreferences();
  ReviewSession? reviewSession;
  final reviewHistory = <ReviewSession>[];

  ReviewSession? startOrResumeReview() {
    if (reviewSession != null && !reviewSession!.completed) {
      return reviewSession;
    }
    final words = [
      ...sampleVocabulary,
      ...personalWords,
    ].where((word) => saved.contains(word.id)).take(20).toList();
    if (words.isEmpty) return null;
    final session = ReviewSession(List.unmodifiable(words));
    reviewSession = session;
    reviewHistory.add(session);
    return session;
  }
}
