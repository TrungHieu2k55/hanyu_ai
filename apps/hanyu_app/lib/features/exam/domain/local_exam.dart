enum ExamSection { listening, reading }

enum LocalExamMode { readingPractice, fullExam }

class LocalExamQuestion {
  LocalExamQuestion({
    required this.id,
    required this.section,
    required this.prompt,
    required List<String> choices,
    required this.correct,
    required this.explanation,
    this.transcript,
    this.audioRef,
  }) : choices = List.unmodifiable(choices) {
    if (id.isEmpty ||
        id.length > 100 ||
        prompt.trim().isEmpty ||
        prompt.runes.length > 3000 ||
        choices.length < 2 ||
        choices.length > 6 ||
        choices.any((c) => c.trim().isEmpty || c.length > 1000) ||
        correct < 0 ||
        correct >= choices.length ||
        explanation.runes.length > 3000) {
      throw const FormatException('Invalid question');
    }
  }
  final String id, prompt, explanation;
  final ExamSection section;
  final List<String> choices;
  final int correct;
  final String? transcript, audioRef;
  Map<String, dynamic> toJson() => {
    'id': id,
    'section': section.name,
    'prompt': prompt,
    'choices': choices,
    'correct': correct,
    'explanation': explanation,
    'transcript': transcript,
    'audioRef': audioRef,
  };
  factory LocalExamQuestion.fromJson(Map<String, dynamic> json) =>
      LocalExamQuestion(
        id: json['id'] as String,
        section: ExamSection.values.byName(json['section'] as String),
        prompt: json['prompt'] as String,
        choices: (json['choices'] as List).cast<String>(),
        correct: json['correct'] as int,
        explanation: json['explanation'] as String,
        transcript: json['transcript'] as String?,
        audioRef: json['audioRef'] as String?,
      );
}

class LocalExamPackage {
  LocalExamPackage({
    required this.id,
    required this.version,
    required this.targetLevel,
    required List<LocalExamQuestion> questions,
    this.approved = false,
    this.sourceRef = '',
  }) : questions = List.unmodifiable(questions);
  final String id, version, sourceRef;
  final int targetLevel;
  final bool approved;
  final List<LocalExamQuestion> questions;
  bool get fromCatalog => id.startsWith('content-');
  bool get readyForReading =>
      !fromCatalog ||
      questions.where((q) => q.section == ExamSection.reading).length == 10;
  bool get readyForFullExam =>
      approved &&
      sourceRef.isNotEmpty &&
      questions.length == 20 &&
      questions.where((q) => q.section == ExamSection.reading).length == 10 &&
      questions.where((q) => q.section == ExamSection.listening).length == 10 &&
      questions
          .where((q) => q.section == ExamSection.listening)
          .every((q) => q.audioRef?.isNotEmpty ?? false);
}

class LocalExamAttempt {
  LocalExamAttempt({
    required this.id,
    required this.packageId,
    required this.packageVersion,
    required this.targetLevel,
    required this.mode,
    required List<LocalExamQuestion> questions,
    required Map<int, int> answers,
    required this.position,
    required this.startedAt,
    required this.deadline,
    required this.submittedAt,
    required this.timedOut,
    required this.correctCount,
  }) : questions = List.unmodifiable(questions),
       answers = Map.unmodifiable(answers);
  final String id, packageId, packageVersion;
  final int targetLevel, position;
  final LocalExamMode mode;
  final List<LocalExamQuestion> questions;
  final Map<int, int> answers;
  final DateTime startedAt, deadline;
  final DateTime? submittedAt;
  final bool timedOut;
  final int? correctCount;
  bool get done => submittedAt != null;
  int get blanks => questions.length - answers.length;
  int remainingSeconds(DateTime now) =>
      (deadline.difference(now.toUtc()).inMicroseconds /
              Duration.microsecondsPerSecond)
          .ceil()
          .clamp(0, 1200);
}

class LocalExamState {
  const LocalExamState({this.attempts = const []});
  final List<LocalExamAttempt> attempts;
  LocalExamAttempt? find(String id) {
    for (final attempt in attempts) {
      if (attempt.id == id) return attempt;
    }
    return null;
  }
}

int gradeLocalExam(List<LocalExamQuestion> questions, Map<int, int> answers) {
  if (answers.entries.any(
    (e) =>
        e.key < 0 ||
        e.key >= questions.length ||
        e.value < 0 ||
        e.value >= questions[e.key].choices.length,
  )) {
    throw const FormatException('Invalid answers');
  }
  return answers.entries
      .where((e) => questions[e.key].correct == e.value)
      .length;
}
