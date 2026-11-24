import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:doanchuyennganh2/core/media/practice_media.dart';
import 'package:doanchuyennganh2/features/practice/domain/local_practice.dart';

final practiceNow = DateTime.utc(2026, 11, 21, 5);
LocalPracticeEntry writing({String id = 'writing', bool done = false}) =>
    LocalPracticeEntry(
      id: id,
      kind: PracticeKind.writing,
      createdAt: practiceNow,
      updatedAt: practiceNow,
      done: done,
      data: {
        'character': '人',
        'manualChoice': null,
        'elapsedMs': 500,
        'strokes': [
          [
            [0.2, 0.3],
            [0.5, 0.8],
          ],
        ],
      },
    );
LocalMediaInput picture([String id = 'image']) => LocalMediaInput(
  id: id,
  mime: 'image/png',
  bytes: Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
);
LocalMediaInput sound([String id = 'sound']) => LocalMediaInput(
  id: id,
  mime: 'audio/wav',
  bytes: pcmToWav(Uint8List(3200)),
);
LocalPracticeEntry photo({String? image = 'image', String text = '你好'}) =>
    LocalPracticeEntry(
      id: 'photo',
      kind: PracticeKind.photo,
      createdAt: practiceNow,
      updatedAt: practiceNow,
      data: {'original': '你好', 'text': text, 'imageId': image},
    );
LocalPracticeEntry conversation() => LocalPracticeEntry(
  id: 'talk',
  kind: PracticeKind.conversation,
  createdAt: practiceNow,
  updatedAt: practiceNow,
  data: {
    'scenarioId': 'tourism',
    'scenarioVersion': 'sample-v1-unreviewed',
    'title': 'Đón khách',
    'role': 'Nhân viên',
    'partner': 'Khách',
    'goal': 'Chào hỏi',
    'opening': ['你好', 'nǐ hǎo', 'xin chào'],
    'reply': ['谢谢', 'xièxie', 'cảm ơn'],
    'draft': '你好',
    'draftAudioId': 'sound',
    'turns': [],
  },
);
