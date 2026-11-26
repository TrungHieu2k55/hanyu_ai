import '../../features/extended_learning/study_preview.dart';
import 'learning_catalog_store.dart';
import '../files/local_file_transfer.dart';
import '../../features/support/domain/local_feedback.dart';

import 'dart:typed_data';

import '../../features/profile/domain/local_profile.dart';

import '../../features/practice/domain/local_practice.dart';

import 'package:doanchuyennganh2/features/exam/domain/local_exam.dart';
import 'package:doanchuyennganh2/features/review/domain/sm2.dart';

import 'local_models.dart';

import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

abstract interface class LocalRepository {
  Future<LocalSnapshot> load();
  Future<StudyPreview> loadStudyPreview();
  Future<StudyPreview> updateStudyPreview(
    StudyPreview Function(StudyPreview) change,
  );
  Future<CatalogInstallPreview> preparePackageInstall(LocalJsonFile file);
  Future<LocalSnapshot> installPackage(
    CatalogInstallPreview preview, {
    required String operationId,
    bool acceptTrial = false,
    bool activate = false,
  });
  Future<LocalSnapshot> activatePackage(
    String? id, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> removePackage(
    String id, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> putWord(
    VocabularyItem word, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveWord(
    String id,
    bool saved, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveNote(
    String id,
    String note, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> deleteWord(
    String id, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> savePreferences(
    LocalPreferences preferences, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveProfile(
    LocalProfile profile, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveHelpSeen(
    String version, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> startReview({
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> revealReview(
    String id,
    int position, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> rateReview(
    String id,
    int position,
    MemoryRating rating, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> startExam(
    String packageId,
    LocalExamMode mode, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveExamAnswer(
    String id,
    int index,
    int? choice, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> moveExam(
    String id,
    int index, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> submitExam(
    String id, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> savePractice(
    LocalPracticeEntry entry, {
    List<LocalMediaInput> media = const [],
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> confirmPracticeTurn(
    String id, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> deletePractice(
    String id, {
    required int revision,
    required String operationId,
  });
  Future<Uint8List?> readMedia(String id);
  Future<Uint8List> exportArchive();
  Future<LocalSnapshot> restoreArchive(
    Uint8List bytes, {
    required int revision,
    required String operationId,
  });
  Future<String> exportBackup();
  Future<LocalSnapshot> restoreBackup(
    String json, {
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> saveFeedback({
    required String id,
    required int reportRevision,
    required String body,
    FeedbackContext? context,
    bool draft = false,
    required int revision,
    required String operationId,
  });
  Future<LocalSnapshot> prepareFeedbackExport(
    String id,
    int reportRevision, {
    required int revision,
    required String operationId,
  });
  Future<LocalJsonFile> feedbackExportFile(String id, int reportRevision);
  Future<LocalSnapshot> markFeedbackExported(
    String id,
    int reportRevision,
    String checksum, {
    required int revision,
    required String operationId,
  });
  Future<FeedbackReceipt> previewFeedbackReceipt(LocalJsonFile file);
  Future<LocalSnapshot> importFeedbackReceipt(
    FeedbackReceipt receipt, {
    required int revision,
    required String operationId,
  });
  Future<void> close();
}
