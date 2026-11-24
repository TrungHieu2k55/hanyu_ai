import '../../../core/files/json_contract.dart';
import '../../../core/local/local_models.dart';

enum ContentKind { vocabulary, question, scenario }

String contentKindLabel(ContentKind kind) => switch (kind) {
  ContentKind.vocabulary => 'Từ vựng',
  ContentKind.question => 'Câu hỏi',
  ContentKind.scenario => 'Tình huống',
};

sealed class ContentPayload {
  const ContentPayload();
  ContentKind get kind;
  String get title;
  Map<String, dynamic> toJson();
  static ContentPayload fromJson(ContentKind kind, Map<String, dynamic> json) =>
      switch (kind) {
        ContentKind.vocabulary => VocabularyContent.fromJson(json),
        ContentKind.question => QuestionContent.fromJson(json),
        ContentKind.scenario => ScenarioContent.fromJson(json),
      };
}

class VocabularyContent extends ContentPayload {
  VocabularyContent({
    required String hanzi,
    required String pinyin,
    required String vietnamese,
    this.targetLevel,
    String exampleHanzi = '',
    String exampleVietnamese = '',
  }) : hanzi = boundedText(hanzi, 30),
       pinyin = boundedText(pinyin, 300),
       vietnamese = boundedText(vietnamese, 300),
       exampleHanzi = boundedText(exampleHanzi, 1000, empty: true),
       exampleVietnamese = boundedText(exampleVietnamese, 1000, empty: true) {
    if (!this.hanzi.runes.any(
      (r) =>
          (r >= 0x3400 && r <= 0x9fff) ||
          (r >= 0xf900 && r <= 0xfaff) ||
          (r >= 0x20000 && r <= 0x3134f),
    )) {
      throw const LocalDataException('Từ vựng cần chứa Hán tự.');
    }
    if (targetLevel != null) boundedInt(targetLevel, 1, 3);
  }
  final String hanzi, pinyin, vietnamese, exampleHanzi, exampleVietnamese;
  final int? targetLevel;
  @override
  ContentKind get kind => ContentKind.vocabulary;
  @override
  String get title => hanzi;
  @override
  Map<String, dynamic> toJson() => {
    'hanzi': hanzi,
    'pinyin': pinyin,
    'vietnamese': vietnamese,
    'targetLevel': targetLevel,
    'exampleHanzi': exampleHanzi,
    'exampleVietnamese': exampleVietnamese,
  };
  factory VocabularyContent.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'hanzi',
      'pinyin',
      'vietnamese',
      'targetLevel',
      'exampleHanzi',
      'exampleVietnamese',
    ]);
    return VocabularyContent(
      hanzi: boundedText(j['hanzi'], 30),
      pinyin: boundedText(j['pinyin'], 300),
      vietnamese: boundedText(j['vietnamese'], 300),
      targetLevel: j['targetLevel'] == null
          ? null
          : boundedInt(j['targetLevel'], 1, 3),
      exampleHanzi: boundedText(j['exampleHanzi'], 1000, empty: true),
      exampleVietnamese: boundedText(j['exampleVietnamese'], 1000, empty: true),
    );
  }
}

class QuestionContent extends ContentPayload {
  QuestionContent({
    required this.targetLevel,
    required this.section,
    required this.slot,
    required String prompt,
    required List<String> choices,
    required this.correctIndex,
    required String explanation,
  }) : prompt = boundedText(prompt, 2000),
       choices = List.unmodifiable(choices.map((v) => boundedText(v, 300))),
       explanation = boundedText(explanation, 2000) {
    boundedInt(targetLevel, 1, 3);
    boundedInt(slot, 1, 10);
    boundedInt(correctIndex, 0, 3);
    if (!['reading', 'listening'].contains(section) ||
        this.choices.length != 4 ||
        this.choices.toSet().length != 4) {
      throw const LocalDataException(
        'Câu hỏi cần bốn đáp án khác nhau và phần nghe/đọc hợp lệ.',
      );
    }
  }
  final int targetLevel, slot, correctIndex;
  final String section, prompt, explanation;
  final List<String> choices;
  @override
  ContentKind get kind => ContentKind.question;
  @override
  String get title => prompt;
  @override
  Map<String, dynamic> toJson() => {
    'targetLevel': targetLevel,
    'section': section,
    'slot': slot,
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'explanation': explanation,
  };
  factory QuestionContent.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'targetLevel',
      'section',
      'slot',
      'prompt',
      'choices',
      'correctIndex',
      'explanation',
    ]);
    final choices = j['choices'];
    if (choices is! List) {
      throw const LocalDataException('Danh sách đáp án không hợp lệ.');
    }
    return QuestionContent(
      targetLevel: boundedInt(j['targetLevel'], 1, 3),
      section: boundedText(j['section'], 20),
      slot: boundedInt(j['slot'], 1, 10),
      prompt: boundedText(j['prompt'], 2000),
      choices: choices.map((v) => boundedText(v, 300)).toList(),
      correctIndex: boundedInt(j['correctIndex'], 0, 3),
      explanation: boundedText(j['explanation'], 2000),
    );
  }
}

class ScenarioContent extends ContentPayload {
  ScenarioContent({
    required this.key,
    required String role,
    required String partner,
    required String goal,
    required List<String> opening,
    required List<String> sampleReply,
    String suggestion = '',
  }) : role = boundedText(role, 200),
       partner = boundedText(partner, 200),
       goal = boundedText(goal, 1000),
       opening = List.unmodifiable(opening.map((v) => boundedText(v, 2000))),
       sampleReply = List.unmodifiable(
         sampleReply.map((v) => boundedText(v, 2000)),
       ),
       suggestion = boundedText(suggestion, 300, empty: true) {
    if (!keys.contains(key) ||
        this.opening.length != 3 ||
        this.sampleReply.length != 3) {
      throw const LocalDataException(
        'Tình huống cần đúng ba phần Hán tự/Pinyin/Việt và thuộc bốn tình huống hiện có.',
      );
    }
  }
  static const keys = ['tourism', 'directions', 'shopping', 'business'];
  static const labels = [
    'Đón khách tại Đà Nẵng',
    'Hỏi đường',
    'Mua hàng Taobao',
    'Giao tiếp thương mại',
  ];
  final String key, role, partner, goal, suggestion;
  final List<String> opening, sampleReply;
  @override
  ContentKind get kind => ContentKind.scenario;
  @override
  String get title => labels[keys.indexOf(key)];
  @override
  Map<String, dynamic> toJson() => {
    'key': key,
    'role': role,
    'partner': partner,
    'goal': goal,
    'opening': opening,
    'sampleReply': sampleReply,
    'suggestion': suggestion,
  };
  factory ScenarioContent.fromJson(Map<String, dynamic> j) {
    jsonKeys(j, [
      'key',
      'role',
      'partner',
      'goal',
      'opening',
      'sampleReply',
      'suggestion',
    ]);
    List<String> triplet(Object? value) {
      if (value is! List) {
        throw const LocalDataException('Thiếu bộ ba Hán tự/Pinyin/Việt.');
      }
      return value.map((v) => boundedText(v, 2000)).toList();
    }

    return ScenarioContent(
      key: boundedText(j['key'], 30),
      role: boundedText(j['role'], 200),
      partner: boundedText(j['partner'], 200),
      goal: boundedText(j['goal'], 1000),
      opening: triplet(j['opening']),
      sampleReply: triplet(j['sampleReply']),
      suggestion: boundedText(j['suggestion'], 300, empty: true),
    );
  }
}
