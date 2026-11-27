import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/practice_media.dart';
import '../../../core/local/local_models.dart';
import '../../../shared/widgets/status_panel.dart';
import '../domain/local_practice.dart';

class RecordingControls extends ConsumerStatefulWidget {
  const RecordingControls({
    required this.onRecording,
    required this.onRecorded,
    this.enabled = true,
    this.recordedMessage =
        'Bản thu tạm đã sẵn sàng. Nghe lại rồi lưu bản nháp.',
    super.key,
  });
  final ValueChanged<bool> onRecording;
  final ValueChanged<LocalMediaInput> onRecorded;
  final bool enabled;
  final String recordedMessage;
  @override
  ConsumerState<RecordingControls> createState() => _RecordingControlsState();
}

class _RecordingControlsState extends ConsumerState<RecordingControls>
    with WidgetsBindingObserver {
  late final PracticeRecorder recorder;
  Timer? timer;
  bool recording = false, working = false, leaveRequested = false;
  late final Stopwatch watch;
  String? message;
  bool permissionDenied = false;
  @override
  void initState() {
    super.initState();
    recorder = ref.read(practiceRecorderFactoryProvider)();
    watch = ref.read(practiceStopwatchFactoryProvider)();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        (state == AppLifecycleState.inactive && recording)) {
      leaveRequested = true;
      if (recording && !working) unawaited(stop());
    }
  }

  Future<void> start() async {
    if (working || recording) return;
    setState(() {
      working = true;
      message = null;
      permissionDenied = false;
      leaveRequested = false;
    });
    widget.onRecording(true);
    try {
      await recorder.start();
      if (!mounted) {
        await recorder.cancel();
        return;
      }
      recording = true;
      watch.reset();
      watch.start();
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (watch.elapsedMilliseconds >= 60000 ||
            recorder.interruption != null) {
          unawaited(stop());
        } else {
          setState(() {});
        }
      });
    } catch (e) {
      widget.onRecording(false);
      if (mounted) {
        setState(() {
          permissionDenied = e is MicrophonePermissionDenied;
          message = switch (e) {
            MicrophonePermissionDenied issue => issue.message,
            LocalDataException issue => issue.message,
            _ => 'Chưa ghi được. Kiểm tra quyền mic/thiết bị; vẫn có thể nhập văn bản.',
          };
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
    if (mounted && recording && leaveRequested) await stop();
  }

  Future<void> stop({bool discard = false}) async {
    if (working || !recording) return;
    setState(() => working = true);
    timer?.cancel();
    watch.stop();
    try {
      final input = await recorder.stop();
      if (mounted) {
        if (input != null && !discard) widget.onRecorded(input);
        setState(
          () => message = discard
              ? 'Đã hủy bản thu tạm.'
              : input == null
              ? 'Chưa có âm thanh thu được. Hãy thử lại hoặc nhập văn bản.'
              : recorder.interruption ?? widget.recordedMessage,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Bản thu bị gián đoạn. Chưa lưu audio; bản chữ vẫn còn.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          working = false;
          recording = false;
        });
        widget.onRecording(false);
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    watch.stop();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(recorder.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (recording)
        Text(
          '${(watch.elapsed.inSeconds ~/ 60).toString().padLeft(2, '0')}:${(watch.elapsed.inSeconds % 60).toString().padLeft(2, '0')} / 01:00 · đang thu âm',
        ),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          if (!recording)
            OutlinedButton.icon(
              onPressed: !widget.enabled || working ? null : start,
              icon: const Icon(Icons.mic_none),
              label: Text(working ? 'Đang mở microphone…' : 'Ghi âm / ghi lại'),
            ),
          if (recording)
            FilledButton(
              onPressed: working ? null : () => stop(),
              child: const Text('Dừng ghi âm'),
            ),
          if (recording)
            TextButton(
              onPressed: working ? null : () => stop(discard: true),
              child: const Text('Hủy bản đang thu'),
            ),
        ],
      ),
      if (message != null)
        if (permissionDenied)
          StatusPanel(
            icon: Icons.mic_off_outlined,
            illustration: SvgPicture.asset(
              'assets/figma/permission-microphone.svg',
            ),
            title: 'Bạn vẫn có thể nhập chữ',
            message: message!,
          )
        else
          Semantics(liveRegion: true, child: Text(message!)),
      const Text(
        'Chỉ thu khi bạn bắt đầu. Chưa tự chuyển giọng nói thành chữ. Bản chưa lưu sẽ mất khi đóng trang.',
      ),
    ],
  );
}
