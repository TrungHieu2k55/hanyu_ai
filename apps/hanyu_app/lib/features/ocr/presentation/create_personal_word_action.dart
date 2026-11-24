import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/personal_word_editor.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';

/// Manual bridge only; never treats OCR text as approved vocabulary.
class CreatePersonalWordAction extends StatefulWidget {
  const CreatePersonalWordAction({
    super.key,
    required this.text,
    required this.words,
    required this.nextId,
    required this.onCreated,
  });
  final String text;
  final List<VocabularyItem> words;
  final String Function() nextId;
  final ValueChanged<VocabularyItem> onCreated;
  @override
  State<CreatePersonalWordAction> createState() =>
      _CreatePersonalWordActionState();
}

class _CreatePersonalWordActionState extends State<CreatePersonalWordAction> {
  bool opening = false;
  Future<void> create() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final source = widget.text.trim();
      final word = await Navigator.push<VocabularyItem>(
        context,
        MaterialPageRoute(
          builder: (_) => DetailScaffold(
            title: 'Từ riêng từ văn bản',
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpansionTile(
                  title: const Text('Văn bản đang tra'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectionArea(child: Text(source)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn một từ cần học rồi tự nhập Pinyin và nghĩa. Không tự đưa vào bộ ôn hoặc công bố thành học liệu chung.',
                ),
                const SizedBox(height: 16),
                PersonalWordEditor(
                  word: null,
                  nextId: widget.nextId,
                  initialHanzi: source.characters.length <= 30 ? source : '',
                  existingWords: widget.words,
                ),
              ],
            ),
          ),
        ),
      );
      if (word != null && mounted) widget.onCreated(word);
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: opening ? null : create,
    icon: const Icon(Icons.edit_note_outlined),
    label: const Text('Tạo từ riêng từ văn bản'),
  );
}
