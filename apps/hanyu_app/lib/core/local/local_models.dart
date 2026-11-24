import '../../features/content/domain/installed_catalog.dart';
import '../../features/support/domain/local_feedback.dart';
import '../../features/practice/domain/local_practice.dart';

import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/features/review/domain/local_review.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

class LocalWord {
  const LocalWord(
    this.entry, {
    this.saved = false,
    this.note = '',
    this.contentRevision,
    this.retained = false,
  });
  final VocabularyItem entry;
  final bool saved;
  final String note;
  final int? contentRevision;
  final bool retained;
  String get sourceLabel => entry.personal
      ? 'Từ riêng · chưa kiểm duyệt'
      : retained
      ? 'Từ đã giữ lại từ gói cũ'
      : contentRevision != null
      ? 'Học liệu trong gói'
      : 'Học liệu mẫu · chưa kiểm duyệt';
  String get sourceVersion => entry.personal
      ? 'personal-local'
      : contentRevision != null
      ? 'r$contentRevision'
      : 'sample-v1-unreviewed';
}

class LocalPreferences {
  const LocalPreferences({
    this.name = '',
    this.level = 1,
    this.minutes = 15,
    this.sound = true,
  });
  final String name;
  final int level, minutes;
  final bool sound;
}

class LocalSnapshot {
  LocalSnapshot({
    required List<LocalWord> words,
    required this.preferences,
    required this.revision,
    this.helpVersionSeen,
    InstalledCatalog? catalog,
    List<FeedbackReport> feedback = const [],
    this.review = const LocalReviewState(),
    this.exams = const LocalExamState(),
    this.practice = const [],
    this.media = const [],
  }) : catalog = catalog ?? InstalledCatalog(),
       words = List.unmodifiable(words),
       feedback = List.unmodifiable(feedback);
  final InstalledCatalog catalog;
  final List<LocalWord> words;
  final LocalPreferences preferences;
  final int revision;
  final String? helpVersionSeen;
  final List<FeedbackReport> feedback;
  final LocalReviewState review;
  final LocalExamState exams;
  final List<LocalPracticeEntry> practice;
  final List<LocalMediaInfo> media;
  LocalWord? find(String id) {
    for (final word in words) {
      if (word.entry.id == id) return word;
    }
    return null;
  }
}

class LocalDataException implements Exception {
  const LocalDataException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocalConflict extends LocalDataException {
  const LocalConflict()
    : super(
        'Dữ liệu đã thay đổi ở nơi khác. Tải lại trước khi lưu tiếp; bản nháp của bạn vẫn giữ trên màn.',
      );
}
