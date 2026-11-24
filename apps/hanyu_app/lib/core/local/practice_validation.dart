import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'local_models.dart';
import '../../features/practice/domain/local_practice.dart';

const maxPracticeEntries = 10000;
const maxMediaEntries = 1000;
const mediaBudget = 50 * 1024 * 1024;
const backupBudget = 60 * 1024 * 1024;
bool validPracticeId(String id) =>
    RegExp(r'^[a-zA-Z0-9:_-]{1,100}$').hasMatch(id);
Never practiceError(String message) => throw LocalDataException(message);
void validateMedia(LocalMediaInput m) {
  if (!validPracticeId(m.id) || m.bytes.isEmpty) {
    practiceError('Tệp không hợp lệ.');
  }
  if (m.mime == 'audio/wav') {
    if (m.bytes.length > 3 * 1024 * 1024) practiceError('Audio vượt 3 MiB.');
    final b = m.bytes;
    String tag(int start) => String.fromCharCodes(b.sublist(start, start + 4));
    if (b.length < 44 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      practiceError('Audio không phải WAV hợp lệ.');
    }
    final v = ByteData.sublistView(b);
    var offset = 12;
    bool format = false;
    int length = 0;
    while (offset + 8 <= b.length) {
      final size = v.getUint32(offset + 4, Endian.little),
          end = offset + 8 + size;
      if (end > b.length) practiceError('Audio bị cắt hoặc hỏng.');
      if (tag(offset) == 'fmt ') {
        if (size < 16 ||
            v.getUint16(offset + 8, Endian.little) != 1 ||
            v.getUint16(offset + 10, Endian.little) != 1 ||
            v.getUint32(offset + 12, Endian.little) != 16000 ||
            v.getUint16(offset + 22, Endian.little) != 16) {
          practiceError('Cần audio WAV mono 16 kHz, PCM 16 bit.');
        }
        format = true;
      }
      if (tag(offset) == 'data') length += size;
      offset = end + (size.isOdd ? 1 : 0);
    }
    if (!format || length <= 0 || length.isOdd || length > 16000 * 2 * 60) {
      practiceError('Audio rỗng hoặc dài quá 60 giây.');
    }
  } else {
    if (!['image/jpeg', 'image/png'].contains(m.mime) ||
        m.bytes.length > 5 * 1024 * 1024) {
      practiceError('Chỉ nhận JPEG/PNG tối đa 5 MiB.');
    }
    final png =
        m.bytes.length >= 8 &&
        m.bytes[0] == 137 &&
        m.bytes[1] == 80 &&
        m.bytes[2] == 78 &&
        m.bytes[3] == 71;
    final jpg =
        m.bytes.length >= 3 &&
        m.bytes[0] == 255 &&
        m.bytes[1] == 216 &&
        m.bytes[2] == 255;
    if ((m.mime == 'image/png' && !png) || (m.mime == 'image/jpeg' && !jpg)) {
      practiceError('Nội dung ảnh không khớp định dạng.');
    }
    final decoder = img.findDecoderForData(m.bytes),
        info = decoder?.startDecode(m.bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > 20000000 ||
        info.numFrames > 1) {
      practiceError('Ảnh lỗi, ảnh động hoặc vượt 20 megapixel.');
    }
    if (decoder!.decodeFrame(0) == null) practiceError('Không đọc được ảnh.');
  }
}

void validatePractice(LocalPracticeEntry e) {
  if (!validPracticeId(e.id) ||
      e.updatedAt.isBefore(e.createdAt) ||
      jsonEncode(e.data).length > 2 * 1024 * 1024) {
    practiceError('Bản luyện không hợp lệ hoặc quá lớn.');
  }
  final d = e.data;
  bool text(String key, int max) =>
      d[key] is String && (d[key] as String).length <= max;
  switch (e.kind) {
    case PracticeKind.writing:
      if (!text('character', 2) ||
          !RegExp(r'^[\u3400-\u9fff]$').hasMatch(d['character']) ||
          d['elapsedMs'] is! int ||
          d['elapsedMs'] < 0 ||
          d['elapsedMs'] > 86400000 ||
          d['strokes'] is! List ||
          (d['strokes'] as List).length > 500 ||
          (d['manualChoice'] != null &&
              (d['manualChoice'] is! String ||
                  !RegExp(r'^[\u3400-\u9fff]$').hasMatch(d['manualChoice'])))) {
        practiceError('Kiểm tra chữ và dữ liệu nét viết.');
      }
      var count = 0;
      for (final stroke in d['strokes'] as List) {
        if (stroke is! List || stroke.isEmpty) {
          practiceError('Nét viết không hợp lệ.');
        }
        for (final point in stroke) {
          if (point is! List ||
              point.length != 2 ||
              point.any((n) => n is! num || !n.isFinite || n < 0 || n > 1)) {
            practiceError('Tọa độ nét ngoài canvas.');
          }
          count++;
        }
      }
      if (count > 20000 || (e.done && count == 0)) {
        practiceError('Canvas trống hoặc quá nhiều điểm.');
      }
    case PracticeKind.photo:
      if (!text('original', 2000) ||
          !text('text', 2000) ||
          ((d['text'] as String).trim().isEmpty && d['imageId'] == null) ||
          e.done) {
        practiceError('Cần ảnh hoặc văn bản tối đa 2.000 ký tự.');
      }
      if (d['imageId'] != null &&
          (d['imageId'] is! String || !validPracticeId(d['imageId']))) {
        practiceError('Tham chiếu ảnh không hợp lệ.');
      }
    case PracticeKind.conversation:
      if (d['draftAudioId'] != null &&
          (d['draftAudioId'] is! String ||
              !validPracticeId(d['draftAudioId']))) {
        practiceError('ID bản thu nháp không hợp lệ.');
      }
      bool scenarioText(String key, int max) =>
          d[key] is String && (d[key] as String).runes.length <= max;
      if (!text('scenarioId', 100) ||
          !text('scenarioVersion', 100) ||
          !text('title', 200) ||
          !scenarioText('role', 200) ||
          !scenarioText('partner', 200) ||
          !scenarioText('goal', 1000) ||
          !text('draft', 300) ||
          d['turns'] is! List ||
          (d['turns'] as List).length > 8) {
        practiceError('Phiên hội thoại không hợp lệ.');
      }
      for (final key in ['opening', 'reply']) {
        if (d[key] is! List ||
            (d[key] as List).length != 3 ||
            (d[key] as List).any(
              (v) => v is! String || v.runes.length > 2000,
            )) {
          practiceError('Thiếu nội dung tình huống mẫu.');
        }
      }
      for (final t in d['turns'] as List) {
        if (t is! Map ||
            (t['audioId'] != null &&
                (t['audioId'] is! String || !validPracticeId(t['audioId']))) ||
            t['text'] is! String ||
            (t['text'] as String).trim().isEmpty ||
            (t['text'] as String).length > 300 ||
            t['at'] is! String ||
            DateTime.tryParse(t['at']) == null) {
          practiceError('Lượt nói không hợp lệ.');
        }
      }
      if ((d['turns'] as List).length == 8 && !e.done) {
        practiceError('Phiên tám lượt phải kết thúc.');
      }
  }
  if (e.mediaIds.any((id) => !validPracticeId(id))) {
    practiceError('Tham chiếu media lỗi.');
  }
}

class PreparedPracticeRestore {
  PreparedPracticeRestore(
    List<LocalPracticeEntry> entries,
    List<LocalMediaInput> media,
  ) : entries = List.unmodifiable(entries),
      media = List.unmodifiable(media);
  final List<LocalPracticeEntry> entries;
  final List<LocalMediaInput> media;
}

PreparedPracticeRestore preparePracticeRestore(
  List raw,
  List<LocalMediaInput> media,
) {
  if (raw.length > maxPracticeEntries || media.length > maxMediaEntries) {
    practiceError('Backup có quá nhiều bản ghi hoặc tệp.');
  }
  final entries = [
    for (final e in raw) LocalPracticeEntry.fromJson(e as Map<String, dynamic>),
  ];
  if (entries.map((e) => e.id).toSet().length != entries.length ||
      media.map((m) => m.id).toSet().length != media.length) {
    practiceError('Backup trùng ID.');
  }
  if (media.fold<int>(0, (n, m) => n + m.bytes.length) > mediaBudget) {
    practiceError('Media trong backup vượt 50 MiB.');
  }
  final byId = {for (final m in media) m.id: m};
  final refs = <String>{};
  for (final m in media) {
    validateMedia(m);
  }
  for (final e in entries) {
    validatePractice(e);
    for (final id in e.mediaIds) {
      final m = byId[id];
      if (m == null ||
          (e.kind == PracticeKind.photo
              ? !m.mime.startsWith('image/')
              : m.mime != 'audio/wav')) {
        practiceError('Tham chiếu media trong backup thiếu hoặc sai loại.');
      }
      refs.add(id);
    }
  }
  if (media.any((m) => !refs.contains(m.id))) {
    practiceError('Backup có tệp không thuộc bản ghi.');
  }
  return PreparedPracticeRestore(entries, media);
}
