import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/local/local_providers.dart';
import '../../core/media/practice_media.dart';
import '../../shared/ui_tokens.dart';
import '../../shared/widgets/learner_surface.dart';
import '../../shared/widgets/presentation_helpers.dart';
import '../../shared/widgets/pronunciation_button.dart';
import '../../shared/widgets/status_panel.dart';
import '../practice/domain/local_practice.dart';
import '../practice/presentation/recording_controls.dart';
import 'study_lesson.dart';
import 'study_preview.dart';
import 'study_preview_controller.dart';

class StudyLessonScreen extends ConsumerStatefulWidget {
  const StudyLessonScreen({
    required this.lesson,
    required this.soundEnabled,
    super.key,
  });
  final StudyLesson lesson;
  final bool soundEnabled;

  @override
  ConsumerState<StudyLessonScreen> createState() => _StudyLessonScreenState();
}

class _StudyLessonScreenState extends ConsumerState<StudyLessonScreen> {
  final input = TextEditingController();
  final order = <int>[];
  int? selected;
  bool? result;
  bool working = false;
  String? error;
  StudyLesson get lesson => widget.lesson;
  bool get isText =>
      lesson.kind == StudyKind.pronunciation ||
      lesson.kind == StudyKind.dictation;
  bool get isOrder => lesson.kind == StudyKind.sentenceOrder;
  bool get locked => working || result != null;
  String get answer => isText
      ? input.text
      : isOrder
      ? order.map((index) => lesson.options[index]).join()
      : selected == null
      ? ''
      : lesson.options[selected!];

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (locked ||
        answer.trim().isEmpty ||
        (isOrder && order.length != lesson.options.length)) {
      return;
    }
    final correct = lesson.checks(answer);
    final now = ref.read(localClockProvider)();
    setState(() {
      working = true;
      error = null;
    });
    try {
      await ref
          .read(studyPreviewProvider.notifier)
          .updatePreview(
            (data) => data.copyWith(
              attempts: [
                StudyAttempt(lesson.id, correct, now),
                ...data.attempts,
              ],
            ),
          );
      if (mounted) setState(() => result = correct);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Chưa lưu được kết quả. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      buildPageTitle(
        lesson.title,
        '${lesson.kind.label} · HSK ${lesson.level}',
      ),
      const SizedBox(height: 20),
      LearnerSplit(
        main: LearnerSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lesson.prompt,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (lesson.reference case final hanzi?) ...[
                const SizedBox(height: 12),
                Text(
                  hanzi,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: brandInk),
                ),
              ],
              if (lesson.pinyin case final pinyin?)
                Text(pinyin, style: const TextStyle(color: brandTeal)),
              if (lesson.audio case final audio?) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PronunciationButton(
                    hanzi: audio,
                    soundEnabled: widget.soundEnabled,
                    label: 'Nghe câu mẫu',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (lesson.kind == StudyKind.pronunciation) ...[
                const _StudyRecording(),
                const SizedBox(height: 12),
              ],
              if (isText)
                TextField(
                  controller: input,
                  enabled: !locked,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: lesson.kind == StudyKind.dictation
                        ? 'Câu bạn nghe được'
                        : 'Nhập lại câu bạn đã nói',
                    alignLabelWithHint: true,
                  ),
                )
              else if (isOrder)
                ..._ordering()
              else
                for (final (index, option) in lesson.options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: locked
                                ? null
                                : () => setState(() => selected = index),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              alignment: Alignment.centerLeft,
                              backgroundColor: index == selected
                                  ? softSurface
                                  : null,
                            ),
                            child: Semantics(
                              selected: index == selected,
                              child: Text(
                                index == selected
                                    ? 'Đã chọn · $option'
                                    : option,
                              ),
                            ),
                          ),
                        ),
                        if (lesson.optionAudio.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          PronunciationButton(
                            hanzi: lesson.optionAudio[index],
                            soundEnabled: widget.soundEnabled,
                            label: 'Nghe $option',
                          ),
                        ],
                      ],
                    ),
                  ),
              if (error case final message?) ...[
                const SizedBox(height: 12),
                Semantics(liveRegion: true, child: Text(message)),
              ],
              const SizedBox(height: 16),
              if (result case final correct?) ...[
                Semantics(
                  liveRegion: true,
                  child: StatusPanel(
                    icon: correct
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    title: correct
                        ? (lesson.kind == StudyKind.pronunciation
                              ? 'Nội dung khớp câu mẫu'
                              : 'Trả lời đúng')
                        : 'Thử lại nhé',
                    message: lesson.feedback,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () => setState(() {
                        input.clear();
                        order.clear();
                        selected = null;
                        result = null;
                      }),
                      child: const Text('Làm lại'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/practice/lessons'),
                      child: const Text('Chọn bài khác'),
                    ),
                  ],
                ),
              ] else
                FilledButton(
                  onPressed:
                      locked ||
                          answer.trim().isEmpty ||
                          (isOrder && order.length != lesson.options.length)
                      ? null
                      : submit,
                  child: Text(working ? 'Đang lưu…' : 'Kiểm tra câu trả lời'),
                ),
            ],
          ),
        ),
        aside: LearnerSurface(
          color: softSurface,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gợi ý', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(lesson.explanation),
                if (MediaQuery.sizeOf(context).width >= 1024) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Trong khu vực này',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  buildActionTile(
                    Icons.menu_book_outlined,
                    'Danh mục luyện tập',
                    'Chọn bài theo cấp hoặc dạng',
                    () => context.go('/practice/lessons'),
                  ),
                  buildActionTile(
                    Icons.fact_check_outlined,
                    'Sổ lỗi cá nhân',
                    'Xem lại bài đã làm',
                    () => context.push('/progress/mistakes'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  );

  List<Widget> _ordering() => [
    Text('Thứ tự của bạn', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    if (order.isEmpty) const Text('Chọn từng từ ở bên dưới.'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (position, index) in order.indexed)
          OutlinedButton(
            onPressed: locked
                ? null
                : () => setState(() => order.removeAt(position)),
            child: Text('${position + 1}. ${lesson.options[index]}'),
          ),
      ],
    ),
    const Divider(height: 24),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (index, option) in lesson.options.indexed)
          OutlinedButton(
            onPressed: locked || order.contains(index)
                ? null
                : () => setState(() => order.add(index)),
            child: Text(option),
          ),
      ],
    ),
  ];
}

class _StudyRecording extends ConsumerStatefulWidget {
  const _StudyRecording();
  @override
  ConsumerState<_StudyRecording> createState() => _StudyRecordingState();
}

class _StudyRecordingState extends ConsumerState<_StudyRecording> {
  PracticePlayer? player;
  LocalMediaInput? clip;
  bool recording = false, playing = false, loading = false;
  StreamSubscription<bool>? subscription;
  String? error;

  Future<void> togglePlayback() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (player == null) {
        player = ref.read(practicePlayerFactoryProvider)();
        subscription = player!.playing.listen(
          (value) {
            if (mounted) setState(() => playing = value);
          },
          onError: (Object _) {
            if (mounted) {
              setState(() {
                playing = false;
                error = 'Chưa phát được bản thu. Hãy thử lại.';
              });
            }
          },
        );
      }
      if (playing) {
        await player!.pause();
      } else {
        await player!.load(clip!.bytes);
        await player!.play();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Chưa phát được bản thu. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    unawaited(subscription?.cancel());
    unawaited(player?.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Bản thu chỉ dùng để nghe lại trên màn này.'),
      const SizedBox(height: 8),
      RecordingControls(
        enabled: !playing && !loading,
        onRecording: (value) => setState(() => recording = value),
        onRecorded: (value) => setState(() => clip = value),
        recordedMessage: 'Đã thu xong. Bạn có thể nghe lại bản thu.',
      ),
      if (clip != null)
        TextButton.icon(
          onPressed: recording || loading ? null : togglePlayback,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          label: Text(playing ? 'Tạm dừng' : 'Nghe lại bản thu'),
        ),
      if (error case final message?) Text(message),
    ],
  );
}
