import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:doanchuyennganh2/core/files/canonical_json.dart';
import 'package:doanchuyennganh2/core/files/local_file_transfer.dart';
import 'package:doanchuyennganh2/core/local/local_models.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_payload.dart';
import 'package:doanchuyennganh2/features/admin/domain/content_revision.dart';
import 'package:doanchuyennganh2/features/content/domain/content_package.dart';
import 'package:doanchuyennganh2/features/content/domain/installed_catalog.dart';

String uid(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
final now = DateTime.utc(2026, 11, 22);
ContentRevision record(int n, {ContentPayload? payload}) => ContentRevision(
  itemId: uid(n),
  revision: 1,
  createdAt: now,
  payload:
      payload ??
      VocabularyContent(hanzi: '朋友', pinyin: 'péngyou', vietnamese: 'bạn'),
);
ContentPackage pack({
  int id = 2,
  int version = 1,
  List<ContentRevision>? records,
}) => ContentPackage.create(
  publisherId: uid(1),
  packageId: uid(id),
  version: version,
  mode: PackageMode.trial,
  exportedAt: now,
  records: records ?? [record(100)],
);
LocalJsonFile external(Map<String, dynamic> j) {
  final payload = Map<String, dynamic>.of(j)..remove('checksum');
  return LocalJsonFile.fromBytes(
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({...payload, 'checksum': canonicalChecksum(payload)}),
      ),
    ),
    name: 'package.json',
    kind: LocalJsonKind.contentPackage,
  );
}

void main() {
  test('canonical contract immutable and excludes private/internal fields', () {
    final input = [record(100)], p = pack(records: [record(100)]);
    final owned = pack(records: input);
    input.clear();
    expect(owned.records, hasLength(1));
    expect(() => p.records.clear(), throwsUnsupportedError);
    final file = p.toFile();
    expect(() => file.bytes[0] = 0, throwsUnsupportedError);
    expect(ContentPackage.fromFile(file).toFile().bytes, file.bytes);
    expect(p.wordId(uid(100)), 'content:${uid(1)}:${uid(100)}');
    expect(
      (p.toJson()['records'] as List).first.keys,
      unorderedEquals([
        'itemId',
        'revision',
        'kind',
        'payload',
        'source',
        'license',
        'review',
        'state',
      ]),
    );
    final reordered = Map<String, dynamic>.fromEntries(
      p.toJson().entries.toList().reversed,
    );
    expect(ContentPackage.fromFile(external(reordered)).checksum, p.checksum);
  });
  test('tamper/unknown fields/foreign formats/noncanonical values reject', () {
    final j = pack().toJson();
    for (final changed in [
      {...j, 'format': 'hanyu-admin-backup'},
      {...j, 'formatVersion': 2},
      {...j, 'formatVersion': 1.0},
      {...j, 'saved': true},
      {...j, 'publisherId': 'seed'},
      {...j, 'exportedAt': '2026-11-22'},
      {...j, 'version': 0},
      {...j, 'mode': 'certified'},
    ]) {
      expect(
        () => ContentPackage.fromFile(external(changed)),
        throwsA(isA<LocalDataException>()),
      );
    }
    final row = Map<String, dynamic>.of((j['records'] as List).first);
    expect(
      () => ContentPackage.fromFile(
        external({
          ...j,
          'records': [
            {...row, 'note': 'private'},
          ],
        }),
      ),
      throwsA(isA<LocalDataException>()),
    );
    final payload = Map<String, dynamic>.of(row['payload']);
    expect(
      () => ContentPackage.fromFile(
        external({
          ...j,
          'records': [
            {
              ...row,
              'payload': {...payload, 'vietnamese': ' bạn '},
            },
          ],
        }),
      ),
      throwsA(isA<LocalDataException>()),
    );
    final tampered = LocalJsonFile.fromBytes(
      Uint8List.fromList(utf8.encode(jsonEncode({...j, 'version': 2}))),
      name: 'bad.json',
      kind: LocalJsonKind.contentPackage,
    );
    expect(
      () => ContentPackage.fromFile(tampered),
      throwsA(isA<LocalDataException>()),
    );
  });
  test('duplicate item/slot/scenario and unreviewed reviewed-mode reject', () {
    expect(
      () => pack(records: [record(100), record(100)]),
      throwsA(isA<LocalDataException>()),
    );
    QuestionContent q() => QuestionContent(
      targetLevel: 1,
      section: 'reading',
      slot: 1,
      prompt: '你好',
      choices: ['a', 'b', 'c', 'd'],
      correctIndex: 0,
      explanation: 'x',
    );
    expect(
      () => pack(
        records: [
          record(100, payload: q()),
          record(101, payload: q()),
        ],
      ),
      throwsA(isA<LocalDataException>()),
    );
    ScenarioContent s() => ScenarioContent(
      key: 'tourism',
      role: 'khách',
      partner: 'bạn',
      goal: 'chào',
      opening: ['你好', 'nǐ hǎo', 'chào'],
      sampleReply: ['你好', 'nǐ hǎo', 'chào'],
    );
    expect(
      () => pack(
        records: [
          record(100, payload: s()),
          record(101, payload: s()),
        ],
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => ContentPackage.create(
        publisherId: uid(1),
        packageId: uid(2),
        version: 1,
        mode: PackageMode.reviewed,
        exportedAt: now,
        records: [record(100)],
      ),
      throwsA(isA<LocalDataException>()),
    );
    final reviewed = ContentRevision(
      itemId: uid(100),
      revision: 1,
      payload: record(100).payload,
      source: 'Tự soạn',
      license: 'Cho phép',
      createdAt: now,
      state: ContentState.published,
      review: ReviewClaim.declare(
        reviewerName: 'Khai báo local',
        reviewedRevision: 1,
        reviewedAt: now,
        note: 'Chưa xác minh danh tính',
      ),
    );
    final p = ContentPackage.create(
      publisherId: uid(1),
      packageId: uid(2),
      version: 1,
      mode: PackageMode.reviewed,
      exportedAt: now,
      records: [reviewed],
    );
    expect(ContentPackage.fromFile(p.toFile()).mode, PackageMode.reviewed);
    expect(
      () => pack(records: [reviewed.withState(ContentState.withdrawn)]),
      throwsA(isA<LocalDataException>()),
    );
  });
  test('record and real UTF-8 byte limits enforced', () {
    expect(
      () => pack(records: List.generate(1001, (i) => record(100 + i))),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => pack(
        records: List.generate(
          1000,
          (i) => record(
            100 + i,
            payload: VocabularyContent(
              hanzi: '朋友',
              pinyin: 'péngyou',
              vietnamese: 'bạn',
              exampleHanzi: '人' * 1000,
              exampleVietnamese: 'x' * 1000,
            ),
          ),
        ),
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
  test(
    'catalog holds 2245 fixture words with immutable retained provenance',
    () {
      final packages = [
        pack(records: List.generate(1000, (i) => record(100 + i))),
        pack(id: 3, records: List.generate(1000, (i) => record(1100 + i))),
        pack(id: 4, records: List.generate(245, (i) => record(2100 + i))),
      ];
      final c = InstalledCatalog(
        packages: packages,
        activePackageId: uid(2),
        receiptHistory: packages.map(CatalogReceipt.fromPackage).toList(),
      );
      expect(c.managedWordCount, 2245);
      final copy = InstalledCatalog.fromJson(c.toJson());
      expect(copy.managedWordCount, 2245);
      expect(copy.activePackageId, uid(2));
      expect(() => copy.packages.clear(), throwsUnsupportedError);
      expect(() => copy.retainedWords.clear(), throwsUnsupportedError);
      final retained = RetainedWordDefinition(
        publisherId: uid(1),
        record: record(9000),
      );
      final r = InstalledCatalog(retainedWords: {retained.id: retained});
      expect(
        InstalledCatalog.fromJson(r.toJson())
            .retainedWords[retained.id]!
            .record
            .source,
        '',
      );
    },
  );
  test('catalog rejects dangling IDs/missing receipts/ownership conflict/downgrade', () {
    final p = pack(), receipt = CatalogReceipt.fromPackage(pack());
    expect(
      () => InstalledCatalog(activePackageId: p.packageId),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => InstalledCatalog(packages: [p]),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => InstalledCatalog(packages: [p, p], receiptHistory: [receipt]),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => InstalledCatalog(
        packages: [p],
        receiptHistory: [receipt, CatalogReceipt.fromPackage(pack(version: 2))],
      ),
      throwsA(isA<LocalDataException>()),
    );
    final other = ContentPackage.create(
      publisherId: uid(99),
      packageId: p.packageId,
      version: 2,
      mode: PackageMode.trial,
      exportedAt: now,
      records: [record(100)],
    );
    expect(
      () => InstalledCatalog(
        packages: [other],
        receiptHistory: [receipt, CatalogReceipt.fromPackage(other)],
      ),
      throwsA(isA<LocalDataException>()),
    );
    expect(
      () => InstalledCatalog(
        retainedWords: {
          'personal:abc': RetainedWordDefinition(
            publisherId: uid(1),
            record: record(100),
          ),
        },
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
  test('aggregate catalog caps include retained definitions and reject kind changes', () {
    final packages = List.generate(
      5,
      (n) => pack(
        id: 10 + n,
        records: List.generate(1000, (i) => record(100 + n * 1000 + i)),
      ),
    );
    final receipts = packages.map(CatalogReceipt.fromPackage).toList();
    expect(
      InstalledCatalog(
        packages: packages,
        receiptHistory: receipts,
      ).managedWordCount,
      5000,
    );
    final extra = RetainedWordDefinition(
      publisherId: uid(1),
      record: record(9999),
    );
    expect(
      () => InstalledCatalog(
        packages: packages,
        receiptHistory: receipts,
        retainedWords: {extra.id: extra},
      ),
      throwsA(isA<LocalDataException>()),
    );
    final six = [...packages, pack(id: 30, records: [])];
    expect(
      () => InstalledCatalog(
        packages: six,
        receiptHistory: six.map(CatalogReceipt.fromPackage).toList(),
      ),
      throwsA(isA<LocalDataException>()),
    );
    final p = pack(),
        q = pack(
          id: 3,
          records: [
            record(
              100,
              payload: QuestionContent(
                targetLevel: 1,
                section: 'reading',
                slot: 1,
                prompt: '?',
                choices: ['a', 'b', 'c', 'd'],
                correctIndex: 0,
                explanation: 'x',
              ),
            ),
          ],
        );
    expect(
      () => InstalledCatalog(
        packages: [p, q],
        receiptHistory: [
          CatalogReceipt.fromPackage(p),
          CatalogReceipt.fromPackage(q),
        ],
      ),
      throwsA(isA<LocalDataException>()),
    );
    final heavy = List.generate(
      5,
      (n) => pack(
        id: 10 + n,
        records: List.generate(
          1000,
          (i) => record(
            100 + n * 1000 + i,
            payload: VocabularyContent(
              hanzi: '朋友',
              pinyin: 'péngyou',
              vietnamese: 'bạn',
              exampleVietnamese: 'x' * 900,
            ),
          ),
        ),
      ),
    );
    expect(
      () => InstalledCatalog(
        packages: heavy,
        receiptHistory: heavy.map(CatalogReceipt.fromPackage).toList(),
      ),
      throwsA(isA<LocalDataException>()),
    );
  });
}
