import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/core/utils/search_normalizer.dart';
import 'package:doanchuyennganh2/features/vocabulary/data/sample_vocabulary.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/confirm_word_removal.dart';
import 'package:doanchuyennganh2/features/vocabulary/presentation/word_detail_screen.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';
import 'package:doanchuyennganh2/shared/widgets/detail_scaffold.dart';
import 'package:doanchuyennganh2/shared/widgets/panel_card.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({
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
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> toggle(VocabularyItem word) async {
    if (widget.saved.contains(word.id)) {
      if (!await confirmWordRemoval(context, word.hanzi) || !mounted) return;
      widget.saved.remove(word.id);
    } else {
      widget.saved.add(word.id);
    }
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final query = normalizeSearch(search.text);
    final words = widget.words
        .where(
          (w) =>
              normalizeSearch('${w.hanzi} ${w.pinyin} ${w.vietnamese}')
                  .contains(query),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildPageTitle(
          'Gom từng từ, mở thêm câu.',
          'Học liệu minh họa chưa kiểm duyệt; chưa xác nhận phân cấp HSK.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Hán tự, Pinyin hoặc nghĩa Việt',
            helperText: 'Có thể gõ không dấu, ví dụ: xuexi.',
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () => setState(search.clear),
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text('${words.length} từ mẫu'),
        const SizedBox(height: 12),
        if (words.isEmpty)
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa tìm thấy từ phù hợp',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('Thử từ ngắn hơn hoặc xóa nội dung tìm kiếm.'),
                TextButton(
                  onPressed: () => setState(search.clear),
                  child: const Text('Xem lại tất cả'),
                ),
              ],
            ),
          ),
        for (final w in words)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          w.hanzi,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: widget.saved.contains(w.id)
                            ? 'Bỏ lưu ${w.hanzi}'
                            : 'Lưu ${w.hanzi}',
                        onPressed: () => toggle(w),
                        icon: Icon(
                          widget.saved.contains(w.id)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          color: brandTeal,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    w.pinyin,
                    style: const TextStyle(color: brandTeal, fontSize: 18),
                  ),
                  Text(w.vietnamese),
                  Text(
                    w.personal
                        ? 'Từ riêng · chưa kiểm duyệt'
                        : 'Từ mẫu · chưa kiểm duyệt',
                    style: const TextStyle(color: mutedText, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: () async {
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
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Xem chi tiết'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
