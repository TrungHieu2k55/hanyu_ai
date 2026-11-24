import '../../../shared/widgets/learner_surface.dart';
import '../../../shared/widgets/hanzi_focus.dart';
import '../../../shared/widgets/pronunciation_button.dart';
import '../../support/presentation/report_content_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:doanchuyennganh2/app/local/local_providers.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/shared/widgets/async_commit_button.dart';
import 'package:doanchuyennganh2/shared/widgets/presentation_helpers.dart';
import 'package:doanchuyennganh2/app/local/local_drafts.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class LocalWordDetail extends ConsumerStatefulWidget {
  const LocalWordDetail({
    required this.word,
    required this.revision,
    required this.soundEnabled,
    super.key,
  });
  final LocalWord word;
  final int revision;
  final bool soundEnabled;
  @override
  ConsumerState<LocalWordDetail> createState() => _LocalWordDetailState();
}

class _LocalWordDetailState extends ConsumerState<LocalWordDetail> {
  late final LocalDrafts drafts;
  @override
  void initState() {
    super.initState();
    drafts = ref.read(localDraftsProvider);
  }

  late final note = TextEditingController(text: widget.word.note);
  late int revision = widget.revision;
  late String savedNote = widget.word.note;
  bool busy = false;
  String? message;
  bool get dirty => note.text != savedNote;
  @override
  void dispose() {
    drafts.clear(this);
    note.dispose();
    super.dispose();
  }

  Future<void> fresh() async {
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Bỏ bản nháp để tải lại?'),
          content: const Text(
            'Ghi chú chưa lưu sẽ được thay bằng dữ liệu mới nhất trên thiết bị.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Giữ bản nháp'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    try {
      await ref.read(localControllerProvider.notifier).reload();
      if (!mounted) return;
      final data = ref.read(localControllerProvider).requireValue;
      final current = data.find(widget.word.entry.id);
      if (current == null) {
        context.go('/learn');
        return;
      }
      setState(() {
        note.text = current.note;
        savedNote = current.note;
        revision = data.revision;
        message = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Chưa tải lại được; bản nháp vẫn giữ.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    drafts.update(this, changed: dirty, saving: busy);
    final word = widget.word;
    final entry = word.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerSurface(
          color: softSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MỤC TỪ',
                style: TextStyle(
                  color: brandTeal,
                  fontSize: 12,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(height: 12),
              HanziFocus(entry.hanzi),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.pinyin,
                      style: const TextStyle(fontSize: 20, color: brandTeal),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PronunciationButton(
                    hanzi: entry.hanzi,
                    soundEnabled: widget.soundEnabled,
                  ),
                ],
              ),
              Text(
                entry.vietnamese,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(word.sourceLabel, style: const TextStyle(color: mutedText)),
            ],
          ),
        ),
        if (entry.exampleHanzi.isNotEmpty) ...[
          const SizedBox(height: 16),
          LearnerSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dùng trong câu',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(entry.exampleHanzi, style: const TextStyle(fontSize: 21)),
                Text(entry.exampleVietnamese),
              ],
            ),
          ),
        ],
        ReportContentButton(
          contentId: entry.id,
          version: word.sourceVersion,
          label: entry.hanzi,
          route: '/words/${entry.id}',
          enabled: !busy,
        ),
        const SizedBox(height: 24),
        AsyncCommitButton(
          enabled: !dirty && !busy,
          label: word.saved ? 'Bỏ khỏi bộ ôn' : 'Lưu vào bộ ôn',
          intentKey: '${entry.id}:${word.saved}:$revision',
          onBusyChanged: (v) {
            if (mounted) setState(() => busy = v);
          },
          onCommit: (operationId) async {
            if (word.saved) {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Bỏ từ khỏi bộ ôn?'),
                  content: const Text('Từ và ghi chú vẫn giữ trên thiết bị.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Giữ từ'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Bỏ khỏi bộ ôn'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
            }
            await ref
                .read(localControllerProvider.notifier)
                .commit(
                  (r) => r.saveWord(
                    entry.id,
                    !word.saved,
                    revision: revision,
                    operationId: operationId,
                  ),
                );
            if (mounted) {
              setState(() {
                revision = ref
                    .read(localControllerProvider)
                    .requireValue
                    .revision;
                message = 'Đã lưu thay đổi trên thiết bị.';
              });
            }
          },
        ),
        const SizedBox(height: 24),
        buildSectionHeading('Ghi chú riêng'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('local-note-input'),
          controller: note,
          enabled: !busy,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          decoration: const InputDecoration(labelText: 'Ghi chú của bạn'),
          onChanged: (_) => setState(() => message = null),
        ),
        const SizedBox(height: 12),
        AsyncCommitButton(
          label: 'Lưu ghi chú',
          intentKey: '${entry.id}:${note.text}:$revision',
          onBusyChanged: (v) {
            if (mounted) setState(() => busy = v);
          },
          onCommit: (operationId) async {
            final value = note.text;
            await ref
                .read(localControllerProvider.notifier)
                .commit(
                  (r) => r.saveNote(
                    entry.id,
                    value,
                    revision: revision,
                    operationId: operationId,
                  ),
                );
            if (mounted) {
              setState(() {
                savedNote = value;
                revision = ref
                    .read(localControllerProvider)
                    .requireValue
                    .revision;
                message = 'Đã lưu ghi chú trên thiết bị.';
              });
            }
          },
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Semantics(liveRegion: true, child: Text(message!)),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy ? null : fresh,
          child: const Text('Tải lại dữ liệu'),
        ),
        if (entry.personal && !dirty) ...[
          OutlinedButton(
            onPressed: busy
                ? null
                : () => context.push(
                    '/words/${Uri.encodeComponent(entry.id)}/edit',
                  ),
            child: const Text('Sửa từ riêng'),
          ),
          const SizedBox(height: 12),
          AsyncCommitButton(
            label: 'Xóa từ riêng',
            intentKey: 'delete:${entry.id}:$revision',
            onCommit: (operationId) async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Xóa từ riêng trên thiết bị?'),
                  content: const Text(
                    'Từ, ghi chú và lựa chọn lưu ôn của từ này sẽ bị xóa.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Xác nhận xóa'),
                    ),
                  ],
                ),
              );
              if (yes != true) return;
              await ref
                  .read(localControllerProvider.notifier)
                  .commit(
                    (r) => r.deleteWord(
                      entry.id,
                      revision: revision,
                      operationId: operationId,
                    ),
                  );
              if (context.mounted) context.go('/review');
            },
          ),
        ],
      ],
    );
  }
}
