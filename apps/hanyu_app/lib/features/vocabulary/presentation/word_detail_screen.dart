import 'package:doanchuyennganh2/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/support/presentation/feedback_screen.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/confirm_word_removal.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/note_editor.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    required this.word,
    required this.saved,
    required this.notes,
    required this.onChanged,
  });
  final VocabularyItem word;
  final Set<String> saved;
  final Map<String, String> notes;
  final VoidCallback onChanged;
  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final isSaved = widget.saved.contains(w.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.personal
                    ? 'Từ riêng · chưa kiểm duyệt'
                    : 'Từ mẫu · chưa kiểm duyệt',
                style: TextStyle(color: mutedText),
              ),
              const SizedBox(height: 16),
              Text(
                w.hanzi,
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                w.pinyin,
                style: const TextStyle(fontSize: 24, color: brandTeal),
              ),
              const SizedBox(height: 8),
              Text(w.vietnamese, style: const TextStyle(fontSize: 22)),
              const Divider(height: 32),
              const Text(
                'Dùng trong câu',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                w.exampleHanzi.isEmpty ? 'Chưa có ví dụ.' : w.exampleHanzi,
                style: const TextStyle(fontSize: 20),
              ),
              Text(w.exampleVietnamese),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () async {
            if (isSaved) {
              if (!await confirmWordRemoval(context, w.hanzi) || !mounted) {
                return;
              }
              widget.saved.remove(w.id);
            } else {
              widget.saved.add(w.id);
            }
            setState(() {});
            widget.onChanged();
          },
          icon: Icon(
            isSaved
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
          ),
          label: Text(isSaved ? 'Bỏ khỏi bộ ôn' : 'Lưu vào bộ ôn mẫu'),
        ),
        const AccountPreviewLink(
          intent: AccountIntent.saveWord,
          label: 'Xem luồng đăng nhập để lưu từ',
        ),
        const SizedBox(height: 24),
        buildSectionHeading('Ghi chú của bạn'),
        const SizedBox(height: 12),
        Text(
          widget.notes[w.id]?.isNotEmpty == true ? widget.notes[w.id]! : 'Thêm cách nhớ hoặc nghĩa riêng. Ghi chú không sửa học liệu chung.',
        ),
        TextButton.icon(
          onPressed: () async {
            final result = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => DetailScaffold(
                  title: 'Ghi chú riêng',
                  body: NoteEditor(initial: widget.notes[w.id] ?? ''),
                ),
              ),
            );
            if (result == null || !mounted) return;
            setState(() => widget.notes[w.id] = result);
            widget.onChanged();
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Sửa ghi chú'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScaffold(
                title: 'Báo lỗi học liệu',
                body: FeedbackScreen(contextLabel: '${w.hanzi} · ${w.pinyin}'),
              ),
            ),
          ),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Báo lỗi từ này'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Phát âm mẫu và hoạt ảnh thứ tự nét chưa được tích hợp.',
          style: TextStyle(color: mutedText, fontSize: 14),
        ),
      ],
    );
  }
}
