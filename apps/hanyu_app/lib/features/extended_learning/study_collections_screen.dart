import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/local/local_models.dart';
import '../../shared/widgets/learner_surface.dart';
import '../../shared/widgets/presentation_helpers.dart';
import '../../shared/widgets/status_panel.dart';
import 'study_preview.dart';
import 'study_tools_widgets.dart';

class StudyCollectionsScreen extends ConsumerWidget {
  const StudyCollectionsScreen({
    required this.snapshot,
    this.deckId,
    super.key,
  });
  final LocalSnapshot snapshot;
  final String? deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StudyDataView(
    builder: (data) {
      final deck = data.decks.where((item) => item.id == deckId).firstOrNull;
      if (deckId != null && deck == null) {
        return StatusPanel(
          icon: Icons.bookmarks_outlined,
          title: 'Bộ từ không còn trên thiết bị',
          message: 'Quay lại danh sách để chọn bộ khác.',
          actionLabel: 'Về bộ từ',
          onAction: () => context.go('/learn/decks'),
        );
      }
      if (deck != null) return _DeckDetail(deck: deck, snapshot: snapshot);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Bộ từ tùy chỉnh',
            'Gom từ đã lưu theo chủ đề của bạn.',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _editName(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Tạo bộ từ'),
            ),
          ),
          const SizedBox(height: 16),
          if (data.decks.isEmpty)
            const StatusPanel(
              icon: Icons.bookmarks_outlined,
              title: 'Chưa có bộ từ',
              message: 'Tạo một bộ rồi chọn từ đã lưu để thêm.',
            )
          else
            for (final deck in data.decks) ...[
              buildActionTile(
                Icons.bookmarks_outlined,
                deck.name,
                '${deck.words.where((id) => snapshot.find(id)?.saved == true).length} từ đang lưu',
                () => context.push('/learn/decks/${deck.id}'),
              ),
              const Divider(height: 1),
            ],
        ],
      );
    },
  );
}

Future<void> _editName(
  BuildContext context,
  WidgetRef ref,
  StudyDeck? deck,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _DeckNameDialog(deck?.name),
  );
  if (!context.mounted || name == null) return;
  final id = deck?.id ?? const Uuid().v4();
  await saveStudyUpdate(
    context,
    ref,
    (data) => data.copyWith(
      decks: [
        if (deck == null) StudyDeck(id, name, const []),
        for (final current in data.decks)
          if (current.id == id)
            StudyDeck(current.id, name, current.words)
          else
            current,
      ],
    ),
  );
}

class _DeckNameDialog extends StatefulWidget {
  const _DeckNameDialog(this.initialName);
  final String? initialName;
  @override
  State<_DeckNameDialog> createState() => _DeckNameDialogState();
}

class _DeckNameDialogState extends State<_DeckNameDialog> {
  final form = GlobalKey<FormState>();
  late final text = TextEditingController(text: widget.initialName);
  void submit() {
    if (form.currentState!.validate()) Navigator.pop(context, text.text.trim());
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialName == null ? 'Tạo bộ từ' : 'Đổi tên bộ từ'),
    scrollable: true,
    content: Form(
      key: form,
      child: TextFormField(
        controller: text,
        maxLength: 80,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => submit(),
        autofocus: true,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nhập tên bộ từ.' : null,
        decoration: const InputDecoration(labelText: 'Tên bộ từ'),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: submit, child: const Text('Lưu')),
    ],
  );
}

class _DeckDetail extends ConsumerWidget {
  const _DeckDetail({required this.deck, required this.snapshot});
  final StudyDeck deck;
  final LocalSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = snapshot.words.where((word) => word.saved).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          deck.name,
          'Chọn từ đã lưu để thêm hoặc bỏ khỏi bộ này.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _editName(context, ref, deck),
              child: const Text('Đổi tên'),
            ),
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Xóa bộ từ?'),
                    content: const Text(
                      'Các từ vẫn nằm trong danh sách đã lưu và lịch ôn của bạn.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('Hủy'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('Xóa bộ'),
                      ),
                    ],
                  ),
                );
                if (confirm != true || !context.mounted) return;
                final ok = await saveStudyUpdate(
                  context,
                  ref,
                  (data) => data.copyWith(
                    decks: data.decks
                        .where((item) => item.id != deck.id)
                        .toList(),
                  ),
                );
                if (ok && context.mounted) context.go('/learn/decks');
              },
              child: const Text('Xóa bộ từ'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (saved.isEmpty)
          StatusPanel(
            icon: Icons.bookmark_border,
            title: 'Chưa có từ để thêm',
            message: 'Tra một từ rồi lưu vào bộ ôn.',
            actionLabel: 'Đi tra từ',
            onAction: () => context.push('/learn/words'),
          )
        else
          LearnerSurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final word in saved)
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      value: deck.words.contains(word.entry.id),
                      title: Text(word.entry.hanzi),
                      subtitle: Text(
                        '${word.entry.pinyin} · ${word.entry.vietnamese}',
                      ),
                      onChanged: (selected) => saveStudyUpdate(
                        context,
                        ref,
                        (data) => data.copyWith(
                          decks: [
                            for (final old in data.decks)
                              if (old.id == deck.id)
                                StudyDeck(old.id, old.name, [
                                  ...old.words.where(
                                    (id) => id != word.entry.id,
                                  ),
                                  if (selected == true) word.entry.id,
                                ])
                              else
                                old,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class StudyLookupHistoryScreen extends ConsumerWidget {
  const StudyLookupHistoryScreen({required this.snapshot, super.key});
  final LocalSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StudyDataView(
    builder: (data) {
      final words = data.history.map(snapshot.find).nonNulls.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildPageTitle(
            'Lịch sử tra cứu',
            'Những từ bạn đã mở gần đây trên thiết bị này.',
          ),
          const SizedBox(height: 12),
          if (words.isEmpty)
            StatusPanel(
              icon: Icons.history,
              title: 'Chưa có lượt tra từ',
              message: 'Mở một mục từ trong từ điển để lưu dấu vào lịch sử.',
              actionLabel: 'Đi tra từ',
              onAction: () => context.push('/learn/words'),
            )
          else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('Xóa lịch sử tra cứu?'),
                      content: const Text('Từ đã lưu và tiến độ ôn vẫn còn.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Xóa lịch sử'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await saveStudyUpdate(
                      context,
                      ref,
                      (data) => data.copyWith(history: const []),
                    );
                  }
                },
                child: const Text('Xóa lịch sử tra cứu'),
              ),
            ),
            for (final word in words)
              buildActionTile(
                Icons.history,
                word.entry.hanzi,
                '${word.entry.pinyin} · ${word.entry.vietnamese}',
                () => context.push(
                  '/words/${Uri.encodeComponent(word.entry.id)}',
                ),
              ),
          ],
        ],
      );
    },
  );
}
