import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';

void main() {
  Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));
  LocalJsonFile valid() => LocalJsonFile.fromBytes(
    bytes('{"label":"你好"}'),
    name: 'hanyu.json',
    kind: LocalJsonKind.feedback,
  );

  test(
    'typed UTF-8 JSON validates bytes, names and immutable owned storage',
    () {
      final input = bytes('{"word":"朋友"}');
      final file = LocalJsonFile.fromBytes(
        input,
        name: 'Báo lỗi (1).json',
        kind: LocalJsonKind.feedback,
      );
      input[0] = 0;
      expect(jsonDecode(file.text)['word'], '朋友');
      expect(() => file.bytes[0] = 0, throwsUnsupportedError);
      for (final bad in [
        bytes('[]'),
        bytes('{broken'),
        Uint8List.fromList([255]),
        Uint8List(0),
        Uint8List(65537),
      ]) {
        expect(
          () => LocalJsonFile.fromBytes(
            bad,
            name: 'x.json',
            kind: LocalJsonKind.feedback,
          ),
          throwsA(isA<LocalDataException>()),
        );
      }
      for (final name in ['../x.json', r'C:\x.json', 'x.zip', 'x\n.json']) {
        expect(
          () => LocalJsonFile.fromBytes(
            bytes('{}'),
            name: name,
            kind: LocalJsonKind.feedback,
          ),
          throwsA(isA<LocalDataException>()),
        );
      }
    },
  );

  test(
    'kind byte caps include UTF-8 encoded size and allow exactly the limit',
    () {
      for (final kind in LocalJsonKind.values) {
        final exact = bytes('{"v":"${'x' * (kind.maxBytes - 8)}"}');
        expect(exact.length, kind.maxBytes);
        expect(
          LocalJsonFile.fromBytes(
            exact,
            name: 'x.json',
            kind: kind,
          ).bytes.length,
          kind.maxBytes,
        );
        expect(
          () => LocalJsonFile.fromBytes(
            bytes('{"v":"${'人' * (kind.maxBytes ~/ 3)}"}'),
            name: 'x.json',
            kind: kind,
          ),
          throwsA(isA<LocalDataException>()),
        );
      }
    },
  );

  test('picker cancellation and invalid file never become a handoff', () async {
    var called = false;
    final canceled = DeviceLocalFileTransfer(
      picker: () async => null,
      handoff: (_) async {
        called = true;
        return FileHandoff.handedOff;
      },
    );
    expect(await canceled.pick(LocalJsonKind.feedback), isNull);
    expect(called, false);
    final invalid = DeviceLocalFileTransfer(
      picker: () async => XFile.fromData(Uint8List(65537), name: 'x.json'),
    );
    await expectLater(
      invalid.pick(LocalJsonKind.feedback),
      throwsA(isA<LocalDataException>()),
    );
  });

  test(
    'save awaits platform handoff and distinguishes cancel/unavailable/error',
    () async {
      final pending = Completer<FileHandoff>();
      var completed = false;
      final adapter = DeviceLocalFileTransfer(
        handoff: (file) {
          expect(file.text, valid().text);
          return pending.future;
        },
      );
      final result = adapter.save(valid()).then((v) {
        completed = true;
        return v;
      });
      await Future<void>.delayed(Duration.zero);
      expect(completed, false);
      pending.complete(FileHandoff.handedOff);
      expect(await result, FileHandoff.handedOff);
      for (final outcome in [FileHandoff.canceled, FileHandoff.unavailable]) {
        expect(
          await DeviceLocalFileTransfer(handoff: (_) async => outcome)
              .save(valid()),
          outcome,
        );
      }
      await expectLater(
        DeviceLocalFileTransfer(
          handoff: (_) async => throw StateError('OS error'),
        ).save(valid()),
        throwsStateError,
      );
    },
  );
}
