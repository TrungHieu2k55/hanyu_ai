import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../features/practice/domain/local_practice.dart';
import '../local/practice_validation.dart';

abstract interface class PracticeImagePicker {
  Future<LocalMediaInput?> pick({required bool camera});
}

final practiceImagePickerProvider = Provider<PracticeImagePicker>(
  (ref) => DeviceImagePicker(),
);

class DeviceImagePicker implements PracticeImagePicker {
  @override
  Future<LocalMediaInput?> pick({required bool camera}) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      practiceError('Ảnh vượt 5 MiB. Chọn JPEG/PNG nhỏ hơn.');
    }
    final bytes = await file.readAsBytes();
    final m = LocalMediaInput(
      id: const Uuid().v4(),
      mime: bytes.isNotEmpty && bytes[0] == 137 ? 'image/png' : 'image/jpeg',
      bytes: bytes,
    );
    validateMedia(m);
    return m;
  }
}

class MicrophonePermissionDenied implements Exception {
  const MicrophonePermissionDenied();

  String get message =>
      'Microphone bị từ chối. Mở quyền trong cài đặt hoặc nhập văn bản.';
}

abstract interface class PracticeRecorder {
  Future<void> start();
  Future<LocalMediaInput?> stop();
  Future<void> cancel();
  Future<void> dispose();
  String? get interruption;
}

final practiceRecorderFactoryProvider = Provider<PracticeRecorder Function()>(
  (ref) => DevicePracticeRecorder.new,
);

Uint8List pcmToWav(Uint8List pcm) {
  final size = pcm.length - pcm.length % 2;
  final out = Uint8List(44 + size), d = ByteData.sublistView(out);
  void tag(int offset, String value) =>
      out.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  d.setUint32(4, 36 + size, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  d.setUint32(16, 16, Endian.little);
  d.setUint16(20, 1, Endian.little);
  d.setUint16(22, 1, Endian.little);
  d.setUint32(24, 16000, Endian.little);
  d.setUint32(28, 32000, Endian.little);
  d.setUint16(32, 2, Endian.little);
  d.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  d.setUint32(40, size, Endian.little);
  out.setRange(44, out.length, pcm);
  return out;
}

class DevicePracticeRecorder implements PracticeRecorder {
  AudioRecorder? recorder;
  StreamSubscription<Uint8List>? subscription;
  BytesBuilder buffer = BytesBuilder(copy: false);
  bool active = false, stopping = false;
  @override
  String? interruption;
  @override
  Future<void> start() async {
    if (active) return;
    recorder ??= AudioRecorder();
    if (!await recorder!.hasPermission()) {
      throw const MicrophonePermissionDenied();
    }
    if (!await recorder!.isEncoderSupported(AudioEncoder.pcm16bits)) {
      practiceError(
        'Thiết bị chưa hỗ trợ ghi âm định dạng này. Hãy nhập văn bản.',
      );
    }
    buffer = BytesBuilder(copy: false);
    interruption = null;
    final stream = await recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    active = true;
    subscription = stream.listen(
      (bytes) {
        final remain = 1920000 - buffer.length;
        if (remain > 0) {
          buffer.add(
            bytes.length > remain
                ? Uint8List.sublistView(bytes, 0, remain)
                : bytes,
          );
        }
      },
      onError: (Object e) {
        interruption = 'Microphone bị gián đoạn. Kiểm tra bản thu rồi thử lại.';
      },
      onDone: () {
        if (active && !stopping) {
          interruption =
              'Thiết bị đã ngừng thu. Có thể nghe lại phần thu được.';
        }
      },
    );
  }

  @override
  Future<LocalMediaInput?> stop() async {
    if (!active) return null;
    stopping = true;
    try {
      await recorder!.stop();
    } finally {
      active = false;
      await subscription?.cancel();
      subscription = null;
      stopping = false;
    }
    final pcm = buffer.takeBytes();
    if (pcm.length < 2) return null;
    return LocalMediaInput(
      id: const Uuid().v4(),
      mime: 'audio/wav',
      bytes: pcmToWav(pcm),
    );
  }

  @override
  Future<void> cancel() async {
    if (active) await stop();
    buffer.clear();
  }

  @override
  Future<void> dispose() async {
    try {
      await cancel();
    } finally {
      await recorder?.dispose();
    }
  }
}

abstract interface class PracticePlayer {
  Future<void> load(Uint8List bytes);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Stream<bool> get playing;
}

final practicePlayerFactoryProvider = Provider<PracticePlayer Function()>(
  (ref) => DevicePracticePlayer.new,
);

class DevicePracticePlayer implements PracticePlayer {
  final AudioPlayer player = AudioPlayer();
  final events = StreamController<bool>.broadcast();
  late final StreamSubscription<PlayerState> subscription;
  DevicePracticePlayer() {
    subscription = player.playerStateStream.listen(
      (s) => events.add(
        s.playing && s.processingState != ProcessingState.completed,
      ),
      onError: events.addError,
    );
  }

  @override
  Stream<bool> get playing => events.stream;
  @override
  Future<void> load(Uint8List bytes) async {
    await player.setUrl(
      Uri.dataFromBytes(bytes, mimeType: 'audio/wav').toString(),
    );
  }

  @override
  Future<void> play() async {
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    unawaited(
      player.play().catchError((Object e) {
        if (!events.isClosed) events.addError(e);
      }),
    );
  }

  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> dispose() async {
    try {
      await Future.wait<void>([subscription.cancel(), player.dispose()]);
    } finally {
      await events.close();
    }
  }
}

final practiceStopwatchFactoryProvider = Provider<Stopwatch Function()>(
  (ref) => Stopwatch.new,
);
