import '../../../core/local/local_models.dart';
import '../../admin/domain/content_payload.dart';
import '../../exam/data/local_exam_packages.dart';
import '../../exam/domain/local_exam.dart';
import '../../roleplay/data/sample_scenarios.dart';
import '../../roleplay/domain/scenario.dart';
import '../domain/installed_catalog.dart';

List<LocalExamPackage> catalogExams(InstalledCatalog catalog) {
  final package = catalog.active;
  if (package == null) return localExamPackages;
  final groups = <int, List<({String id, QuestionContent question})>>{};
  for (final record in package.records) {
    if (record.payload case final QuestionContent question) {
      groups.putIfAbsent(question.targetLevel, () => []).add((
        id: record.itemId,
        question: question,
      ));
    }
  }
  return [
    for (final level in [1, 2, 3])
      if (groups[level] case final rows?)
        LocalExamPackage(
          id: 'content-${package.packageId}-$level',
          version: 'v${package.version}',
          sourceRef: package.publisherId,
          targetLevel: level,
          questions: [
            for (final row
                in rows..sort((a, b) {
                  final section = a.question.section.compareTo(
                    b.question.section,
                  );
                  return section == 0
                      ? a.question.slot.compareTo(b.question.slot)
                      : section;
                }))
              LocalExamQuestion(
                id: row.id,
                section: ExamSection.values.byName(row.question.section),
                prompt: row.question.prompt,
                choices: row.question.choices,
                correct: row.question.correctIndex,
                explanation: row.question.explanation,
              ),
          ],
        ),
  ];
}

List<Scenario> catalogScenarios(InstalledCatalog catalog) {
  final package = catalog.active;
  if (package == null) return sampleScenarios;
  return [
    for (final record in package.records)
      if (record.payload case final ScenarioContent s)
        Scenario(
          s.key,
          s.title,
          s.role,
          s.partner,
          s.goal,
          s.opening,
          s.sampleReply,
          s.suggestion,
          version:
              '${package.packageId}:v${package.version}:r${record.revision}',
        ),
  ];
}

Iterable<LocalWord> catalogWords(LocalSnapshot snapshot) {
  final active = snapshot.catalog.active;
  if (active == null) {
    return snapshot.words.where((w) => !w.entry.id.startsWith('content:'));
  }
  final ids = {
    for (final record in active.records)
      if (record.kind == ContentKind.vocabulary) active.wordId(record.itemId),
  };
  return snapshot.words.where(
    (w) => w.entry.personal || ids.contains(w.entry.id),
  );
}
