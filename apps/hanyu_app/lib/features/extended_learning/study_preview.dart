class StudyAttempt {
  const StudyAttempt(this.lessonId, this.correct, this.at);
  final String lessonId;
  final bool correct;
  final DateTime at;
  factory StudyAttempt.fromJson(Map<String, dynamic> data) => StudyAttempt(
    data['lessonId'] as String,
    data['correct'] as bool,
    DateTime.parse(data['at'] as String),
  );
  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'correct': correct,
    'at': at.toUtc().toIso8601String(),
  };
}

class StudyDeck {
  const StudyDeck(this.id, this.name, this.words);
  final String id, name;
  final List<String> words;
  factory StudyDeck.fromJson(Map<String, dynamic> data) => StudyDeck(
    data['id'] as String,
    data['name'] as String,
    (data['words'] as List).cast<String>(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'words': words};
}

class StudyReminder {
  const StudyReminder({
    this.enabled = false,
    this.hour = 19,
    this.minute = 0,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
  });
  final bool enabled;
  final int hour, minute;
  final List<int> weekdays;
  factory StudyReminder.fromJson(Map<String, dynamic> data) => StudyReminder(
    enabled: data['enabled'] as bool,
    hour: data['hour'] as int,
    minute: data['minute'] as int,
    weekdays: (data['weekdays'] as List).cast<int>(),
  );
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'weekdays': weekdays,
  };
}

class StudyPreview {
  const StudyPreview({
    this.attempts = const [],
    this.decks = const [],
    this.history = const [],
    this.offlineLevels = const [],
    this.reminder = const StudyReminder(),
  });
  final List<StudyAttempt> attempts;
  final List<StudyDeck> decks;
  final List<String> history;
  final List<int> offlineLevels;
  final StudyReminder reminder;

  StudyPreview copyWith({
    List<StudyAttempt>? attempts,
    List<StudyDeck>? decks,
    List<String>? history,
    List<int>? offlineLevels,
    StudyReminder? reminder,
  }) => StudyPreview(
    attempts: attempts ?? this.attempts,
    decks: decks ?? this.decks,
    history: history ?? this.history,
    offlineLevels: offlineLevels ?? this.offlineLevels,
    reminder: reminder ?? this.reminder,
  );

  factory StudyPreview.fromJson(Map<String, dynamic> data) => StudyPreview(
    attempts: (data['attempts'] as List)
        .cast<Map<String, dynamic>>()
        .map(StudyAttempt.fromJson)
        .toList(),
    decks: (data['decks'] as List)
        .cast<Map<String, dynamic>>()
        .map(StudyDeck.fromJson)
        .toList(),
    history: (data['history'] as List).cast<String>(),
    offlineLevels: (data['offlineLevels'] as List).cast<int>(),
    reminder: StudyReminder.fromJson(data['reminder'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'attempts': attempts.map((a) => a.toJson()).toList(),
    'decks': decks.map((deck) => deck.toJson()).toList(),
    'history': history,
    'offlineLevels': offlineLevels,
    'reminder': reminder.toJson(),
  };
}
