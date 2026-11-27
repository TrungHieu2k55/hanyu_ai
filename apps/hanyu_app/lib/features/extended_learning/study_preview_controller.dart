import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/local/local_providers.dart';
import 'study_preview.dart';

final studyPreviewProvider =
    AsyncNotifierProvider<StudyPreviewController, StudyPreview>(
      StudyPreviewController.new,
    );

class StudyPreviewController extends AsyncNotifier<StudyPreview> {
  @override
  Future<StudyPreview> build() =>
      ref.watch(localRepositoryProvider).loadStudyPreview();

  Future<void> updatePreview(
    StudyPreview Function(StudyPreview current) change,
  ) async {
    final committed = await ref
        .read(localRepositoryProvider)
        .updateStudyPreview(change);
    if (ref.mounted) state = AsyncData(committed);
  }

  Future<void> recordLookup(String id) => updatePreview(
    (data) => data.copyWith(
      history: [
        id,
        ...data.history.where((item) => item != id),
      ].take(100).toList(),
    ),
  );
}
