class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.level,
    required this.hanzi,
    required this.pinyin,
    required this.vietnamese,
    required this.exampleHanzi,
    required this.exampleVietnamese,
    this.favorite = false,
    this.personal = false,
  });

  final String id;
  final int? level;
  final String hanzi;
  final String pinyin;
  final String vietnamese;
  final String exampleHanzi;
  final String exampleVietnamese;
  final bool favorite;
  final bool personal;

  VocabularyItem copyWith({bool? favorite}) => VocabularyItem(
    id: id,
    level: level,
    hanzi: hanzi,
    pinyin: pinyin,
    vietnamese: vietnamese,
    exampleHanzi: exampleHanzi,
    exampleVietnamese: exampleVietnamese,
    favorite: favorite ?? this.favorite,
    personal: personal,
  );
}
