import '../../../shared/ui_tokens.dart';
import '../../../shared/widgets/learner_surface.dart';
import '../../support/presentation/report_content_button.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/local/local_providers.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../roleplay/domain/scenario.dart';
import '../domain/local_practice.dart';
import 'practice_widgets.dart';
import 'recording_controls.dart';

class LocalConversationEditor extends ConsumerStatefulWidget {
  const LocalConversationEditor({this.entry, this.scenario, super.key});
  final LocalPracticeEntry? entry;
  final Scenario? scenario;
  @override
  ConsumerState<LocalConversationEditor> createState() =>
      _LocalConversationEditorState();
}

class _LocalConversationEditorState
    extends PracticeEditorState<LocalConversationEditor> {
  late final id = widget.entry?.id ?? const Uuid().v4();
  late final created = widget.entry?.createdAt ?? DateTime.now().toUtc();
  late final editor = TextEditingController(
    text: widget.entry?.data['draft'] as String? ?? '',
  );
  late String? audioId = widget.entry?.data['draftAudioId'] as String?;
  LocalMediaInput? input;
  bool recording = false, showSample = false;
  Map<String, dynamic> get source => widget.entry?.data ?? initialScenario;
  late final Map<String, dynamic> initialScenario = {
    'scenarioId': widget.scenario!.id,
    'scenarioVersion': widget.scenario!.version,
    'title': widget.scenario!.title,
    'role': widget.scenario!.role,
    'partner': widget.scenario!.partner,
    'goal': widget.scenario!.goal,
    'opening': widget.scenario!.opening,
    'reply': widget.scenario!.reply,
    'turns': [],
  };
  @override
  String get intent => jsonEncode([editor.text, audioId]);
  @override
  void initState() {
    super.initState();
    if (widget.entry == null) initialScenario;
    saved = intent;
  }

  @override
  void didUpdateWidget(covariant LocalConversationEditor old) {
    super.didUpdateWidget(old);
    // After a committed confirmation, the saved draft was consumed into a turn.
    if ((old.entry?.data['turns'] as List? ?? []).length !=
        (widget.entry?.data['turns'] as List? ?? []).length) {
      editor.text = widget.entry!.data['draft'] as String;
      audioId = widget.entry!.data['draftAudioId'] as String?;
      input = null;
      saved = intent;
      revision = ref.read(localControllerProvider).requireValue.revision;
    }
  }

  Future<void> save(String op, {bool end = false}) async {
    final entry = LocalPracticeEntry(
      id: id,
      kind: PracticeKind.conversation,
      createdAt: created,
      updatedAt: created,
      done: end,
      data: {...source, 'draft': editor.text, 'draftAudioId': audioId},
    );
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.savePractice(
            entry,
            media: input == null ? [] : [input!],
            revision: revision,
            operationId: op,
          ),
        );
    await committed();
    if (mounted && widget.entry == null) context.go('/conversations/$id');
  }

  @override
  void dispose() {
    editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.entry?.done ?? false;
    drafts.update(this, changed: saved != intent, saving: busy || recording);
    final turns = source['turns'] as List,
        opening = source['opening'] as List,
        reply = source['reply'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          source['title'] as String,
          done
              ? 'Phiên thủ công đã kết thúc · ${turns.length}/8 lượt'
              : 'Luyện hội thoại thủ công · ${turns.length}/8 lượt · chưa có AI',
        ),
        ReportContentButton(
          contentId: source['scenarioId'] as String,
          version: source['scenarioVersion'] as String,
          label: source['title'] as String,
          route: '/conversations/new?scenario=${source['scenarioId']}',
          enabled: !busy && !recording,
        ),
        const SizedBox(height: 16),
        LearnerSplit(
          sidebarFirstOnNarrow: true,
          main: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Câu mở đầu mẫu · chưa kiểm duyệt',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final line in opening) Text(line as String),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < turns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lượt ${i + 1} · bạn tự nhập'),
                      Text((turns[i] as Map)['text'] as String),
                      if ((turns[i] as Map)['audioId'] case final String audio)
                        LocalAudioPlayer(mediaId: audio, key: ValueKey(audio)),
                    ],
                  ),
                ),
              if (!done) ...[
                LearnerSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Câu trả lời tiếp theo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      RecordingControls(
                        enabled: !busy,
                        onRecording: (v) {
                          if (mounted) setState(() => recording = v);
                        },
                        onRecorded: (m) => setState(() {
                          input = m;
                          audioId = m.id;
                        }),
                      ),
                      const SizedBox(height: 16),
                      if (audioId != null) ...[
                        LocalAudioPlayer(
                          mediaId: input == null ? audioId : null,
                          input: input,
                          key: ValueKey(audioId),
                        ),
                        TextButton(
                          onPressed: busy || recording
                              ? null
                              : () => setState(() {
                                  audioId = null;
                                  input = null;
                                }),
                          child: const Text('Bỏ audio của bản nháp, giữ chữ'),
                        ),
                      ],
                      TextField(
                        controller: editor,
                        enabled: !busy && !recording,
                        minLines: 3,
                        maxLines: 8,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: 'Bản chữ bạn tự nhập',
                          helperText: 'Không phải transcript từ giọng nói; chưa kiểm tra ngữ pháp/phát âm.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      AsyncCommitButton(
                        label: 'Lưu phiên và bản nháp',
                        intentKey: 'conversation:$id:$intent',
                        enabled: !busy && !recording,
                        onBusyChanged: onBusy,
                        onCommit: (op) => save(op),
                      ),
                      const SizedBox(height: 12),
                      AsyncCommitButton(
                        label: 'Xác nhận thêm lượt',
                        intentKey: 'confirm-turn:$id:${turns.length}',
                        enabled:
                            widget.entry != null &&
                            saved == intent &&
                            editor.text.trim().isNotEmpty &&
                            !busy &&
                            !recording,
                        onBusyChanged: onBusy,
                        onCommit: (op) async {
                          await ref
                              .read(localControllerProvider.notifier)
                              .commit(
                                (r) => r.confirmPracticeTurn(
                                  id,
                                  revision: revision,
                                  operationId: op,
                                ),
                              );
                          await committed();
                        },
                      ),
                      const Text(
                        'Lưu bản nháp trước rồi xác nhận để tính một lượt. Ghi/nghe lại không tăng lượt.',
                      ),
                      const SizedBox(height: 16),
                      AsyncCommitButton(
                        label: 'Kết thúc phiên',
                        compact: true,
                        intentKey: 'end-conversation:$id:$intent',
                        enabled: !busy && !recording,
                        onBusyChanged: onBusy,
                        onCommit: (op) async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Kết thúc phiên thủ công?'),
                              content: const Text(
                                'Các lượt và bản nháp được giữ để xem lại; phiên kết thúc không thêm lượt mới.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Làm tiếp'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Kết thúc'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true) await save(op, end: true);
                        },
                      ),
                    ],
                  ),
                ),
                reloadButton(),
              ] else if ((source['draft'] as String? ?? '').isNotEmpty ||
                  source['draftAudioId'] != null) ...[
                const Text('Bản nháp cuối · chưa tính vào số lượt'),
                Text(source['draft'] as String? ?? ''),
                if (source['draftAudioId'] case final String audio)
                  LocalAudioPlayer(
                    mediaId: audio,
                    key: ValueKey('draft:$audio'),
                  ),
              ],
              TextButton(
                onPressed: () => setState(() => showSample = !showSample),
                child: Text(showSample ? 'Ẩn câu đáp mẫu' : 'Xem câu đáp mẫu'),
              ),
              if (showSample) ...[
                const Text(
                  'Mẫu cố định để tham khảo · không phải phản hồi AI cho câu của bạn',
                ),
                for (final line in reply) Text(line as String),
              ],
              const SizedBox(height: 16),
              if (saved == intent)
                _ConversationWords(
                  text: turns.map((t) => (t as Map)['text']).join(' '),
                  revision: revision,
                  onSaved: committed,
                  onBusy: onBusy,
                  enabled: !busy && !recording,
                ),
            ],
          ),
          aside: LearnerSurface(
            color: softSurface,
            child: Text(
              'Vai của bạn: ${source['role']}\nĐối tác trong tình huống: ${source['partner']}\nMục tiêu: ${source['goal']}',
            ),
          ),
        ),
        TextButton(
          onPressed: busy || recording
              ? null
              : () => context.go('/conversations'),
          child: const Text('Về các tình huống'),
        ),
      ],
    );
  }
}

class _ConversationWords extends ConsumerWidget {
  const _ConversationWords({
    required this.text,
    required this.revision,
    required this.onSaved,
    required this.onBusy,
    required this.enabled,
  });
  final String text;
  final int revision;
  final Future<void> Function() onSaved;
  final ValueChanged<bool> onBusy;
  final bool enabled;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(localControllerProvider).requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final word in d.words.where((w) => text.contains(w.entry.hanzi)))
          PracticeWordAction(
            word: word,
            revision: revision,
            scope: 'conversation',
            enabled: enabled,
            onBusy: onBusy,
            onSaved: onSaved,
          ),
      ],
    );
  }
}
