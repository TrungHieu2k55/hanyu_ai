import '../../../shared/widgets/async_commit_button.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local/local_providers.dart';
import '../../../app/local/local_drafts.dart';
import '../../../core/local/local_models.dart';
import '../../../core/media/practice_media.dart';
import '../domain/local_practice.dart';

String practicePath(PracticeKind kind) => switch (kind) {
  PracticeKind.writing => '/writing',
  PracticeKind.photo => '/photos',
  PracticeKind.conversation => '/conversations',
};

abstract class PracticeEditorState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  late final LocalDrafts drafts;
  late int revision;
  bool busy = false;
  String saved = '';
  String get intent;
  @override
  void initState() {
    super.initState();
    drafts = ref.read(localDraftsProvider);
    revision = ref.read(localControllerProvider).requireValue.revision;
  }

  void track() => drafts.update(this, changed: saved != intent, saving: busy);
  void onBusy(bool value) {
    if (mounted) setState(() => busy = value);
  }

  Future<void> committed() async {
    if (!mounted) return;
    setState(() {
      revision = ref.read(localControllerProvider).requireValue.revision;
      saved = intent;
    });
    drafts.update(this, changed: false, saving: false);
  }

  Widget reloadButton() => TextButton(
    onPressed: busy
        ? null
        : () async {
            onBusy(true);
            try {
              await ref.read(localControllerProvider.notifier).reload();
              if (mounted) {
                setState(
                  () => revision = ref
                      .read(localControllerProvider)
                      .requireValue
                      .revision,
                );
              }
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chưa tải lại được. Bản đang soạn vẫn giữ.'),
                  ),
                );
              }
            } finally {
              onBusy(false);
            }
          },
    child: const Text('Tải lại dữ liệu, giữ bản đang soạn'),
  );
  @override
  void dispose() {
    drafts.clear(this);
    super.dispose();
  }
}

class SavedImage extends ConsumerStatefulWidget {
  const SavedImage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<SavedImage> createState() => _SavedImageState();
}

class _SavedImageState extends ConsumerState<SavedImage> {
  late Future<Uint8List?> bytes = ref
      .read(localRepositoryProvider)
      .readMedia(widget.id);
  @override
  void didUpdateWidget(covariant SavedImage old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      bytes = ref.read(localRepositoryProvider).readMedia(widget.id);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: bytes,
    builder: (_, s) {
      if (s.hasError) {
        return const Text('Chưa tải được ảnh; văn bản đã lưu vẫn còn.');
      }
      if (s.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (s.data == null) {
        return const Text('Ảnh không còn trên thiết bị. Văn bản vẫn còn.');
      }
      return Image.memory(
        s.data!,
        height: 240,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Text('Ảnh không đọc được.'),
      );
    },
  );
}

class LocalAudioPlayer extends ConsumerStatefulWidget {
  const LocalAudioPlayer({this.mediaId, this.input, super.key});
  final String? mediaId;
  final LocalMediaInput? input;
  @override
  ConsumerState<LocalAudioPlayer> createState() => _LocalAudioPlayerState();
}

class _LocalAudioPlayerState extends ConsumerState<LocalAudioPlayer>
    with WidgetsBindingObserver {
  PracticePlayer? player;
  StreamSubscription<bool>? sub;
  bool loading = false, playing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> clear() async {
    final oldSub = sub, oldPlayer = player;
    sub = null;
    player = null;
    try {
      await Future.wait<void>([
        if (oldSub != null) oldSub.cancel(),
        if (oldPlayer != null) oldPlayer.dispose(),
      ]);
    } catch (_) {
      // The device may disappear during teardown. Both cleanup calls have
      // already been issued; leaving the screen must still be safe.
    }
  }

  @override
  void didUpdateWidget(covariant LocalAudioPlayer old) {
    super.didUpdateWidget(old);
    if (old.mediaId != widget.mediaId || old.input?.id != widget.input?.id) {
      unawaited(clear());
      playing = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(
        (player?.pause() ?? Future<void>.value()).catchError((Object _) {}),
      );
    }
  }

  Future<void> toggle() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (playing) {
        await player!.pause();
        return;
      }
      if (player == null) {
        final bytes =
            widget.input?.bytes ??
            (widget.mediaId == null
                ? null
                : await ref
                      .read(localRepositoryProvider)
                      .readMedia(widget.mediaId!));
        if (bytes == null) {
          throw const LocalDataException(
            'Audio không còn; bản chữ vẫn được giữ.',
          );
        }
        if (!mounted) return;
        player = ref.read(practicePlayerFactoryProvider)();
        sub = player!.playing.listen(
          (p) {
            if (mounted) setState(() => playing = p);
          },
          onError: (Object e) {
            if (mounted) {
              setState(
                () => error = 'Không phát được audio. Có thể đọc bản chữ.',
              );
            }
          },
        );
        await player!.load(bytes);
      }
      if (!mounted) return;
      await player!.play();
    } catch (e) {
      await clear();
      if (mounted) {
        setState(
          () => error = e is LocalDataException
              ? e.message
              : 'Chưa phát được audio. Bản chữ vẫn còn.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(clear());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OutlinedButton.icon(
        onPressed: loading ? null : toggle,
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        label: Text(
          loading
              ? 'Đang tải audio…'
              : playing
              ? 'Tạm dừng audio'
              : 'Nghe bản thu',
        ),
      ),
      if (error != null) Text(error!),
    ],
  );
}

/// Stack content and action so large text never fights ListTile height limits.
class PracticeWordAction extends ConsumerWidget {
  const PracticeWordAction({
    required this.word,
    required this.revision,
    required this.scope,
    this.enabled = true,
    this.onBusy,
    this.onSaved,
    super.key,
  });
  final LocalWord word;
  final int revision;
  final String scope;
  final bool enabled;
  final ValueChanged<bool>? onBusy;
  final Future<void> Function()? onSaved;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${word.entry.hanzi} · ${word.entry.pinyin}'),
        Text(word.entry.vietnamese),
        const SizedBox(height: 8),
        AsyncCommitButton(
          compact: true,
          label: word.saved ? 'Đã lưu ôn' : 'Lưu từ vào ôn',
          intentKey: '$scope-word:${word.entry.id}',
          enabled: enabled && !word.saved,
          onBusyChanged: onBusy,
          onCommit: (op) async {
            await ref
                .read(localControllerProvider.notifier)
                .commit(
                  (r) => r.saveWord(
                    word.entry.id,
                    true,
                    revision: revision,
                    operationId: op,
                  ),
                );
            await onSaved?.call();
          },
        ),
      ],
    ),
  );
}
