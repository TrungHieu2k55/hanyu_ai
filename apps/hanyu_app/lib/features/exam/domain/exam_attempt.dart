import 'dart:collection';

import 'package:doanchuyennganh2/features/exam/domain/sample_question.dart';

/// UI preview attempt. Production deadlines must be enforced by the backend.
class ExamAttempt {
  ExamAttempt(
    this.number,
    this.level, {
    required List<SampleQuestion> questions,
    DateTime Function()? clock,
    this.duration = const Duration(minutes: 20),
  }) : questions = List.unmodifiable(
         questions.map(
           (q) => SampleQuestion(
             q.prompt,
             List.unmodifiable(q.choices),
             q.correct,
             q.explanation,
           ),
         ),
       ),
       _clock = clock ?? DateTime.now {
    if (questions.isEmpty) {
      throw ArgumentError.value(
        questions,
        'questions',
        'Cannot start an empty attempt',
      );
    }
    if (duration <= Duration.zero ||
        questions.any(
          (q) =>
              q.choices.isEmpty ||
              q.correct < 0 ||
              q.correct >= q.choices.length,
        )) {
      throw ArgumentError('Invalid preview attempt duration or answer key');
    }
    createdAt = _clock().toUtc();
    deadline = createdAt.add(duration);
  }
  final int number, level;
  final List<SampleQuestion> questions;
  final Duration duration;
  final DateTime Function() _clock;
  late final DateTime createdAt, deadline;
  final _answers = <int, int>{};
  Map<int, int> get answers => UnmodifiableMapView(_answers);
  int index = 0;
  bool _done = false, _timedOut = false;
  bool get done => _done;
  bool get timedOut => _timedOut;
  int get remainingSeconds =>
      (deadline.difference(_clock().toUtc()).inMicroseconds /
              Duration.microsecondsPerSecond)
          .ceil()
          .clamp(0, duration.inSeconds);
  int get correct =>
      _answers.entries.where((e) => questions[e.key].correct == e.value).length;
  int get blanks => questions.length - _answers.length;
  bool selectAnswer(int question, int choice) {
    if (_done) return false;
    if (remainingSeconds == 0) {
      finish(timeout: true);
      return false;
    }
    if (question < 0 ||
        question >= questions.length ||
        choice < 0 ||
        choice >= questions[question].choices.length) {
      return false;
    }
    _answers[question] = choice;
    return true;
  }

  void finish({bool timeout = false}) {
    if (_done) return;
    _done = true;
    _timedOut = timeout || !_clock().toUtc().isBefore(deadline);
  }
}
