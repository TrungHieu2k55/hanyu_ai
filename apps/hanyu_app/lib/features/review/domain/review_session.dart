import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

class ReviewSession {
  final createdAt = DateTime.now().toUtc();
  ReviewSession(this.words);
  final List<VocabularyItem> words;
  int index = 0;
  bool revealed = false;
  final ratings = <String>[];
  bool get completed => index >= words.length;
}
