import 'package:doanchuyennganh2/shared/widgets/status_panel.dart';
import 'package:doanchuyennganh2/shared/widgets/figma_icon.dart';

import '../../content/application/learning_catalog.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/core/utils/search_normalizer.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class LocalVocabularyScreen extends StatefulWidget {
  const LocalVocabularyScreen({
    required this.data,
    this.savedOnly = false,
    this.embedded = false,
    this.afterSearch,
    super.key,
  });
  final LocalSnapshot data;
  final bool savedOnly, embedded;
  final Widget? afterSearch;
  @override
  State<LocalVocabularyScreen> createState() => _LocalVocabularyScreenState();
}

class _LocalVocabularyScreenState extends State<LocalVocabularyScreen> {
  String query = '';
  bool personalOnly = false;
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
        if (!searchFirst) const SizedBox(height: 24),
        TextField(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Từ riêng của tôi'),
              selected: personalOnly,
              onSelected: (v) => setState(() {
                personalOnly = v;
                page = 0;
              }),
            ),
            Chip(label: Text('${words.length} từ')),
          ],
        ),
        const SizedBox(height: 16),
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
            message: widget.savedOnly
                ? 'Chưa có từ khớp. Mở chi tiết một từ rồi chọn lưu vào bộ ôn.'
                : 'Không có từ khớp. Thử cách tìm khác hoặc thêm từ riêng.',
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
            onTap: () =>
                context.push('/words/${Uri.encodeComponent(word.entry.id)}'),
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
