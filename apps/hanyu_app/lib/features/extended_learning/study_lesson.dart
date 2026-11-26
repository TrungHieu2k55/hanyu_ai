enum StudyKind {
  pinyin('Pinyin và thanh điệu'),
  radical('Bộ thủ và cấu tạo chữ'),
  grammar('Ngữ pháp'),
  sentenceOrder('Ghép câu'),
  pronunciation('Luyện nói từng câu'),
  dictation('Nghe chép chính tả');

  const StudyKind(this.label);
  final String label;
}

class StudyLesson {
  const StudyLesson({
    required this.id,
    required this.kind,
    required this.title,
    required this.prompt,
    required this.explanation,
    required this.feedback,
    required this.answer,
    this.level = 1,
    this.options = const [],
    this.audio,
    this.reference,
    this.pinyin,
    this.optionAudio = const [],
  });
  final String id, title, prompt, explanation, feedback, answer;
  final int level;
  final StudyKind kind;
  final List<String> options, optionAudio;
  final String? audio, reference, pinyin;

  bool checks(String input) {
    String normalized(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s，。！？、,.!?]'), '');
    return input.trim().isNotEmpty && normalized(input) == normalized(answer);
  }
}

const studyLessons = [
  StudyLesson(
    id: 'pinyin-four-tones',
    kind: StudyKind.pinyin,
    title: 'Bốn thanh điệu với ma',
    prompt: 'Âm nào mang thanh 3?',
    explanation:
        'Mā cao và ngang. Má đi lên. Mǎ hạ rồi lên khi đọc riêng. Mà đi xuống.',
    options: ['mā', 'má', 'mǎ', 'mà'],
    optionAudio: ['妈', '麻', '马', '骂'],
    answer: 'mǎ',
    feedback: 'Dấu ˇ trong mǎ biểu thị thanh 3.',
  ),
  StudyLesson(
    id: 'radical-person',
    kind: StudyKind.radical,
    title: 'Bộ Nhân trong 你',
    prompt: 'Bộ nào đứng bên trái chữ 你?',
    reference: '你',
    explanation: 'Dạng đứng của 人 là 亻.',
    options: ['亻', '口', '木'],
    answer: '亻',
    feedback: 'Chữ 你 (nǐ) có bộ 亻 bên trái.',
  ),
  StudyLesson(
    id: 'grammar-ma',
    kind: StudyKind.grammar,
    title: 'Câu hỏi với 吗',
    prompt: 'Câu nào hỏi «Bạn là học sinh à?»',
    explanation: 'Đặt 吗 cuối câu trần thuật để tạo câu hỏi có/không.',
    options: ['你是学生吗？', '我是学生。'],
    answer: '你是学生吗？',
    feedback: '吗 đứng ở cuối câu hỏi có/không.',
  ),
  StudyLesson(
    id: 'grammar-because',
    kind: StudyKind.grammar,
    title: 'Nguyên nhân và kết quả',
    level: 2,
    prompt: '因为下雨，___ 我坐公交车。',
    explanation: '因为 giới thiệu nguyên nhân.',
    options: ['所以', '但是', '或者'],
    answer: '所以',
    feedback: '所以 có nghĩa «cho nên».',
  ),
  StudyLesson(
    id: 'grammar-concession',
    kind: StudyKind.grammar,
    title: 'Diễn đạt sự nhượng bộ',
    level: 3,
    prompt: '虽然他很忙，___ 他每天都学习。',
    explanation: '虽然 giới thiệu một điều được thừa nhận.',
    options: ['所以', '但是', '因为'],
    answer: '但是',
    feedback: '虽然…但是… tương đương «tuy… nhưng…».',
  ),
  StudyLesson(
    id: 'sentence-school',
    kind: StudyKind.sentenceOrder,
    title: 'Ghép câu đi học',
    prompt: 'Xếp thành câu «Tôi đi đến trường».',
    explanation: 'Từ nào là chủ ngữ? Động từ nằm ở đâu?',
    options: ['学校', '去', '我'],
    answer: '我去学校',
    feedback: '我去学校。 Tôi đi đến trường.',
  ),
  StudyLesson(
    id: 'pronunciation-intro',
    kind: StudyKind.pronunciation,
    title: 'Tự giới thiệu',
    prompt: 'Nghe câu mẫu rồi nói lại.',
    reference: '你好，我叫小明。',
    pinyin: 'Nǐ hǎo, wǒ jiào Xiǎomíng.',
    explanation: 'Ghi âm để tự nghe lại. Nhập lại câu bạn đã nói để so nội dung với câu mẫu.',
    audio: '你好，我叫小明。',
    answer: '你好我叫小明',
    feedback: '你好，我叫小明。 Xin chào, tôi tên là Tiểu Minh.',
  ),
  StudyLesson(
    id: 'dictation-tea',
    kind: StudyKind.dictation,
    title: 'Nghe và viết lại câu',
    prompt: 'Nghe rồi nhập câu bằng chữ Hán.',
    explanation: 'Bạn có thể nghe lại trước khi kiểm tra.',
    audio: '我喝茶。',
    answer: '我喝茶',
    feedback: '我喝茶。 Tôi uống trà.',
  ),
];
