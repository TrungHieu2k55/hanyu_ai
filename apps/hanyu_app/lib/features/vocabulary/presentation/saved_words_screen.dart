import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/word_detail_screen.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class SavedWordsScreen extends StatefulWidget {
  const SavedWordsScreen({
    super.key,
    this.words = sampleVocabulary,
    required this.saved,
    required this.notes,
    required this.onChanged,
  });
  final List<VocabularyItem> words;
  final Set<String> saved;
  final Map<String, String> notes;
  final VoidCallback onChanged;
  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> {
  @override
  Widget build(BuildContext context) {
    final words = widget.words
        .where((w) => widget.saved.contains(w.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPageTitle(
          'Từ đã lưu',
          '${words.length} từ trong bộ ôn mẫu. Chọn một từ để xem hoặc sửa ghi chú.',
        ),
        const SizedBox(height: 24),
        if (words.isEmpty)
          const PanelCard(
            child: Text(
              'Bộ từ đang trống. Quay lại Học để tìm và lưu từ đầu tiên.',
            ),
          ),
        for (final w in words)
          buildActionTile(
            Icons.bookmark_outline,
            '${w.hanzi} · ${w.pinyin}',
            w.vietnamese,
            () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScaffold(
                    title: 'Chi tiết từ',
                    body: WordDetailScreen(
                      word: w,
                      saved: widget.saved,
                      notes: widget.notes,
                      onChanged: widget.onChanged,
                    ),
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
      ],
    );
  }
}
