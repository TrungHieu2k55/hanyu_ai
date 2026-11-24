import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/personal_word_editor.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/word_detail_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class PersonalWordsScreen extends StatefulWidget {
  const PersonalWordsScreen({
    super.key,
    required this.words,
    required this.saved,
    required this.notes,
    required this.nextId,
    required this.onChanged,
  });
  final List<VocabularyItem> words;
  final Set<String> saved;
  final Map<String, String> notes;
  final String Function() nextId;
  final VoidCallback onChanged;
  @override
  State<PersonalWordsScreen> createState() => _PersonalWordsScreenState();
}

class _PersonalWordsScreenState extends State<PersonalWordsScreen> {
  Future<void> edit(VocabularyItem? word) async {
    final result = await Navigator.push<VocabularyItem>(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScaffold(
          title: word == null ? 'Thêm từ cá nhân' : 'Sửa từ cá nhân',
          body: PersonalWordEditor(
            word: word,
            nextId: widget.nextId,
            existingWords: widget.words,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (word == null) {
        widget.words.add(result);
      } else {
        widget.words[widget.words.indexWhere((w) => w.id == word.id)] = result;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        'Từ của riêng bạn',
        'Bạn tự nhập Hán tự, Pinyin và nghĩa. Từ riêng chưa kiểm duyệt, không thay đổi từ điển chung.',
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm từ cá nhân'),
      ),
      const SizedBox(height: 24),
      if (widget.words.isEmpty)
        const PanelCard(
          child: Text(
            'Chưa có từ cá nhân. Thêm một từ và dùng nút lưu nếu muốn đưa vào bộ ôn mẫu.',
          ),
        ),
      for (final word in List.of(widget.words))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(word.hanzi, style: const TextStyle(fontSize: 30)),
                Text(
                  word.pinyin,
                  style: const TextStyle(color: brandTeal, fontSize: 18),
                ),
                Text(word.vietnamese),
                const SizedBox(height: 12),
                const Text(
                  'Từ riêng · chưa kiểm duyệt',
                  style: TextStyle(color: mutedText, fontSize: 14),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailScaffold(
                          title: 'Chi tiết từ riêng',
                          body: WordDetailScreen(
                            word: word,
                            saved: widget.saved,
                            notes: widget.notes,
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  child: const Text('Mở và lưu vào bộ ôn'),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () => edit(word),
                      child: const Text('Sửa từ riêng'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            title: const Text('Xóa từ riêng mẫu?'),
                            content: const Text(
                              'Từ và ghi chú sẽ bị bỏ khỏi danh sách/bộ ôn mẫu. Phiên ôn đang dở vẫn giữ bộ thẻ đã chụp trước đó. Không sửa học liệu chung.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog, false),
                                child: const Text('Giữ lại'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialog, true),
                                child: const Text('Xóa từ riêng mẫu'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true && mounted) {
                          setState(() {
                            widget.words.removeWhere((w) => w.id == word.id);
                            widget.saved.remove(word.id);
                            widget.notes.remove(word.id);
                          });
                          widget.onChanged();
                        }
                      },
                      child: const Text('Xóa từ riêng'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
