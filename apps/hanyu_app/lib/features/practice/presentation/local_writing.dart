import 'package:doanchuyennganh2/shared/widgets/learner_surface.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/local/local_providers.dart';
import '../../../shared/widgets/handwriting_pad.dart';
import '../../../shared/widgets/async_commit_button.dart';
import '../../../shared/widgets/presentation_helpers.dart';
import '../../writing/data/writing_samples.dart';
import '../domain/local_practice.dart';
import 'practice_widgets.dart';

class LocalWritingEditor extends ConsumerStatefulWidget {
  const LocalWritingEditor({this.entry, super.key});
  final LocalPracticeEntry? entry;
  @override
  ConsumerState<LocalWritingEditor> createState() => _LocalWritingEditorState();
}

class _LocalWritingEditorState extends PracticeEditorState<LocalWritingEditor>
    with WidgetsBindingObserver {
  late final id = widget.entry?.id ?? const Uuid().v4();
  late final created = widget.entry?.createdAt ?? DateTime.now().toUtc();
  late final character = TextEditingController(
    text: widget.entry?.data['character'] as String? ?? '人',
  );
  late final choice = TextEditingController(
    text: widget.entry?.data['manualChoice'] as String? ?? '',
  );
  late final strokes = <List<Offset>>[
    for (final stroke in widget.entry?.data['strokes'] as List? ?? [])
      [
        for (final p in stroke as List)
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
  ];
  late int elapsed = widget.entry?.data['elapsedMs'] as int? ?? 0;
  final watch = Stopwatch();
  int points = 0;
  bool full = false, accepting = false;
  Map<String, dynamic> get content => {
    'character': character.text.trim(),
    'manualChoice': choice.text.trim().isEmpty ? null : choice.text.trim(),
    'strokes': [
      for (final stroke in strokes)
        [
          for (final p in stroke) [p.dx, p.dy],
        ],
    ],
    'elapsedMs': elapsed,
  };
  @override
  String get intent => jsonEncode(content);
  @override
  void initState() {
    super.initState();
    saved = intent;
    points = strokes.fold(0, (n, s) => n + s.length);
    WidgetsBinding.instance.addObserver(this);
  }

  void stopWriting() {
    if (watch.isRunning) {
      watch.stop();
      elapsed += watch.elapsedMilliseconds;
      watch.reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) stopWriting();
  }

  Future<void> save(bool done, String operationId) async {
    stopWriting();
    final entry = LocalPracticeEntry(
      id: id,
      kind: PracticeKind.writing,
      data: content,
      createdAt: created,
      updatedAt: created,
      done: done,
    );
    await ref
        .read(localControllerProvider.notifier)
        .commit(
          (r) => r.savePractice(
            entry,
            revision: revision,
            operationId: operationId,
          ),
        );
    await committed();
    if (mounted && widget.entry == null) context.go('/writing/$id');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    watch.stop();
    character.dispose();
    choice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.entry?.done ?? false;
    track();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildPageTitle(
          done ? 'Bài viết đã hoàn thành' : 'Viết chậm, nhớ mặt chữ',
          'Lưu nét bút để xem lại. Chưa chấm nét, nhận diện CNN hoặc cho điểm.',
        ),
        const SizedBox(height: 24),
        if (!done)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in writingSamples)
                OutlinedButton(
                  onPressed: busy || strokes.isNotEmpty
                      ? null
                      : () => setState(() => character.text = s.$1),
                  child: Text(s.$1),
                ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: character,
          enabled: !busy && !done && strokes.isEmpty,
          maxLength: 1,
          decoration: const InputDecoration(labelText: 'Một Hán tự mục tiêu'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ô luyện chữ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('Viết trong ô lưới, rồi lưu để xem lại.'),
              const SizedBox(height: 16),
              HandwritingPad(
                strokes: strokes,
                enabled: !busy && !done,
                onStart: (p) {
                  accepting = false;
                  if (strokes.length >= 500 || points >= 20000) {
                    setState(() => full = true);
                    return;
                  }
                  accepting = true;
                  watch.start();
                  setState(() {
                    strokes.add([p]);
                    points++;
                  });
                },
                onUpdate: (p) {
                  if (!accepting || strokes.isEmpty || points >= 20000) return;
                  setState(() {
                    strokes.last.add(p);
                    points++;
                  });
                },
                onEnd: () => setState(() {
                  accepting = false;
                  stopWriting();
                }),
              ),
              const SizedBox(height: 16),
              Text(
                '${strokes.length} nét · ${(elapsed / 1000).round()} giây đặt bút',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (full)
          const Text(
            'Đã đạt giới hạn nét/điểm của lượt này. Hãy lưu hoặc viết lại.',
          ),
        if (!done) ...[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy || strokes.isEmpty
                    ? null
                    : () => setState(() {
                        points -= strokes.removeLast().length;
                      }),
                child: const Text('Hoàn tác'),
              ),
              OutlinedButton(
                onPressed: busy || strokes.isEmpty
                    ? null
                    : () => setState(() {
                        stopWriting();
                        strokes.clear();
                        points = 0;
                        full = false;
                      }),
                child: const Text('Viết lại'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: choice,
            enabled: !busy,
            maxLength: 1,
            decoration: const InputDecoration(
              labelText: 'Chữ bạn tự chọn (không bắt buộc)',
              helperText: 'Đây là lựa chọn thủ công, không phải dự đoán CNN.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          AsyncCommitButton(
            label: 'Lưu bản nháp viết',
            intentKey: 'writing:$id:$intent',
            enabled: !busy,
            onBusyChanged: onBusy,
            onCommit: (op) => save(false, op),
          ),
          const SizedBox(height: 12),
          AsyncCommitButton(
            label: 'Hoàn thành lượt luyện',
            intentKey: 'finish-writing:$id:$intent',
            enabled: !busy && strokes.isNotEmpty,
            onBusyChanged: onBusy,
            onCommit: (op) => save(true, op),
          ),
          reloadButton(),
        ] else ...[
          const Text('Chỉ xem lại. Luyện lại tạo lượt mới; chưa có điểm viết.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/writing/new'),
            child: const Text('Luyện một lượt mới'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          saved == intent
              ? 'Nội dung trên màn đã khớp bản lưu hoặc chưa có thay đổi.'
              : 'Có thay đổi chưa lưu; đóng trang sẽ mất phần này.',
        ),
        const Text(
          'Cuộn ngoài ô để di chuyển trang. Chỉ bản đã lưu mới mở lại được sau reload.',
        ),
        TextButton(
          onPressed: busy ? null : () => context.go('/writing'),
          child: const Text('Về lịch sử viết'),
        ),
      ],
    );
  }
}
