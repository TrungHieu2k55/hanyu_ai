import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';

import '../../content/application/learning_catalog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../extended_learning/study_preview_controller.dart';

import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/utils/search_normalizer.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class LocalVocabularyScreen extends ConsumerStatefulWidget {
  const LocalVocabularyScreen({
    required this.data,
    this.savedOnly = false,
    this.embedded = false,
    this.afterSearch,
    this.initialQuery = '',
    super.key,
  });
  final LocalSnapshot data;
  final bool savedOnly, embedded;
  final Widget? afterSearch;
  final String initialQuery;
  @override
  ConsumerState<LocalVocabularyScreen> createState() =>
      _LocalVocabularyScreenState();
}

class _LocalVocabularyScreenState extends ConsumerState<LocalVocabularyScreen> {
  int? level;
  late String query = widget.initialQuery;
  late final search = TextEditingController(text: query);

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  bool personalOnly = false;
  bool withExamples = false;
  String? wordClass;

  Future<void> _openWord(LocalWord word) async {
    if (!widget.savedOnly) {
      try {
        await ref
            .read(studyPreviewProvider.notifier)
            .recordLookup(word.entry.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa lưu được lượt tra từ.')),
          );
        }
      }
    }
    if (mounted) context.push('/words/${Uri.encodeComponent(word.entry.id)}');
  }

  int page = 0;
  @override
  Widget build(BuildContext context) {
    final normalized = normalizeSearch(query);
    final words =
        (widget.savedOnly ? widget.data.words : catalogWords(widget.data))
            .where(
              (w) =>
                  (!widget.savedOnly || w.saved) &&
                  (!personalOnly || w.entry.personal) &&
                  (level == null || w.entry.level == level) &&
                  (!withExamples || w.entry.exampleHanzi.trim().isNotEmpty) &&
                  (wordClass == null || w.entry.partOfSpeech == wordClass) &&
                  normalizeSearch(
                    '${w.entry.hanzi} ${w.entry.pinyin} ${w.entry.vietnamese}',
                  ).contains(normalized),
            )
            .toList();
    final last = words.isEmpty ? 0 : (words.length - 1) ~/ 50;
    final current = page.clamp(0, last);
    final searchFirst = widget.afterSearch != null;
    final dictionaryHeading = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        buildSectionHeading('Tra từ'),
        TextButton(
          onPressed: () => context.push('/learn/words'),
          child: const Text('Mở từ điển'),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded && !searchFirst)
          dictionaryHeading
        else if (!widget.embedded)
          buildPageTitle(
            widget.savedOnly ? 'Bộ từ đã lưu' : 'Tra từ',
            widget.savedOnly
                ? 'Từ và ghi chú được lưu trên thiết bị này. Lịch ôn SM-2 nằm ở tab Ôn tập.'
                : widget.data.catalog.active != null
                ? 'Từ trong gói đang dùng và bộ từ riêng của bạn.'
                : 'Học từ mẫu và xây bộ từ của riêng bạn. Nội dung mẫu chưa được kiểm duyệt HSK.',
          ),
        if (!widget.embedded) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/learn/decks'),
                icon: const Icon(Icons.bookmarks_outlined),
                label: const Text('Bộ từ tùy chỉnh'),
              ),
              if (!widget.savedOnly)
                TextButton.icon(
                  onPressed: () => context.push('/learn/history'),
                  icon: const Icon(Icons.history),
                  label: const Text('Lịch sử tra cứu'),
                ),
            ],
          ),
        ],
        if (!searchFirst) const SizedBox(height: 18),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onChanged: (v) => setState(() {
            query = v;
            page = 0;
          }),
          decoration: const InputDecoration(
            labelText: 'Tìm từ vựng',
            hintText: 'Hán tự, Pinyin, nghĩa Việt',
            prefixIcon: Center(
              widthFactor: 1,
              child: FigmaIcon(FigmaGlyph.search),
            ),
          ),
        ),
        if (searchFirst) ...[
          if (normalized.isEmpty) ...[
            const SizedBox(height: 16),
            widget.afterSearch!,
            const SizedBox(height: 16),
          ],
          dictionaryHeading,
        ],
        const SizedBox(height: 12),
        if (!widget.embedded && !widget.savedOnly) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final choice in [null, 1, 2, 3])
                ChoiceChip(
                  label: Text(choice == null ? 'Tất cả' : 'HSK $choice'),
                  selected: level == choice,
                  selectedColor: brandTeal,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: level == choice ? Colors.white : mutedText,
                  ),
                  shape: const StadiumBorder(),
                  side: BorderSide(
                    color: level == choice ? brandTeal : controlBorder,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  onSelected: (_) => setState(() {
                    level = choice;
                    if (choice != null) personalOnly = false;
                    page = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Từ riêng của tôi'),
              selected: personalOnly,
              onSelected: (v) => setState(() {
                personalOnly = v;
                if (v) level = null;
                page = 0;
              }),
            ),
            if (!widget.embedded && !widget.savedOnly)
              FilterChip(
                label: const Text('Có ví dụ'),
                selected: withExamples,
                onSelected: (value) => setState(() {
                  withExamples = value;
                  page = 0;
                }),
              ),
            Chip(label: Text('${words.length} từ')),
          ],
        ),
        const SizedBox(height: 16),
        if (!widget.embedded && !widget.savedOnly) ...[
          DropdownButtonFormField<String?>(
            initialValue: wordClass,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Loại từ'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Tất cả loại từ'),
              ),
              for (final type in ['Danh từ', 'Động từ', 'Tính từ'])
                DropdownMenuItem<String?>(value: type, child: Text(type)),
            ],
            onChanged: (value) => setState(() {
              wordClass = value;
              page = 0;
            }),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () => context.push('/personal/new'),
          icon: const Icon(Icons.add),
          label: const Text('Thêm từ riêng'),
        ),
        if (!widget.savedOnly) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/learn/catalog'),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('Gói học liệu'),
          ),
        ],
        const SizedBox(height: 12),
        if (words.isEmpty)
          StatusPanel(
            icon: Icons.search_off_outlined,
            title: 'Không có kết quả',
            message: level != null
                ? 'Thử bỏ lọc cấp để xem thêm từ khớp.'
                : widget.savedOnly
                ? 'Chưa có từ khớp. Mở chi tiết một từ rồi chọn lưu vào bộ ôn.'
                : 'Không có từ khớp. Thử cách tìm khác hoặc thêm từ riêng.',
            actionLabel: level != null ? 'Bỏ lọc cấp' : null,
            onAction: level != null
                ? () => setState(() {
                    level = null;
                    page = 0;
                  })
                : null,
          ),
        for (final word in words.skip(current * 50).take(50)) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              word.entry.hanzi,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.entry.pinyin,
                    style: const TextStyle(fontSize: 18, color: brandTeal),
                  ),
                  Text(word.entry.vietnamese),
                  Text(word.sourceLabel, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            trailing: Icon(
              word.saved ? Icons.bookmark : Icons.chevron_right,
              color: brandTeal,
            ),
            onTap: () => _openWord(word),
          ),
          const Divider(),
        ],
        if (last > 0)
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: current == 0
                    ? null
                    : () => setState(() => page = current - 1),
                child: const Text('Trang trước'),
              ),
              Text('${current + 1}/${last + 1}'),
              TextButton(
                onPressed: current == last
                    ? null
                    : () => setState(() => page = current + 1),
                child: const Text('Trang sau'),
              ),
            ],
          ),
      ],
    );
  }
}
