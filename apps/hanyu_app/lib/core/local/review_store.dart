import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:doanchuyennganh2/features/review/domain/local_review.dart';
import 'package:doanchuyennganh2/features/review/domain/sm2.dart';
import 'package:doanchuyennganh2/features/vocabulary/domain/vocabulary_item.dart';

import 'local_database.dart';
import 'local_models.dart';

/// Called inside the repository transaction; never commits UI state itself.
class ReviewStore {
  ReviewStore(this.db, this.clock);
  final LocalDatabase db;
  final DateTime Function() clock;

  Future<void> initializeMissing() async {
    final words = await (db.select(
      db.localWords,
    )..where((w) => w.saved.equals(true))).get();
    for (final word in words) {
      await db
          .into(db.localSchedules)
          .insert(
            LocalSchedulesCompanion.insert(
              wordId: word.id,
              dueAt: clock().toUtc(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> setSaved(String id, bool saved) async {
    if (saved) {
      await db
          .into(db.localSchedules)
          .insert(
            LocalSchedulesCompanion.insert(wordId: id, dueAt: clock().toUtc()),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await (db.update(db.localSchedules)..where((s) => s.wordId.equals(id)))
        .write(LocalSchedulesCompanion(active: Value(saved)));
  }

  Map<String, dynamic> card(StoredWord word) => {
    'id': word.id,
    'hanzi': word.hanzi,
    'pinyin': word.pinyin,
    'meaning': word.meaning,
    'personal': word.personal,
    'exampleHanzi': word.exampleHanzi,
    'exampleVietnamese': word.exampleVietnamese,
  };
  VocabularyItem readCard(Map<String, dynamic> row) => VocabularyItem(
    id: row['id'],
    level: null,
    hanzi: row['hanzi'],
    pinyin: row['pinyin'],
    vietnamese: row['meaning'],
    personal: row['personal'],
    exampleHanzi: row['exampleHanzi'],
    exampleVietnamese: row['exampleVietnamese'],
  );

  Future<LocalReviewState> load() async {
    final schedules =
        await (db.select(db.localSchedules)..where(
              (s) =>
                  s.active.equals(true) &
                  s.dueAt.isSmallerOrEqualValue(clock().toUtc()),
            ))
            .get();
    final sessions = await (db.select(
      db.localReviewSessions,
    )..orderBy([(s) => OrderingTerm.desc(s.createdAt)])).get();
    final events = await (db.select(
      db.localReviewEvents,
    )..orderBy([(e) => OrderingTerm.asc(e.position)])).get();
    return LocalReviewState(
      dueCount: schedules.length,
      eventCount: events.length,
      events: List.unmodifiable(
        events.map(
          (event) => LocalReviewEvent(
            id: event.id,
            wordId: event.wordId,
            sessionId: event.sessionId,
            quality: event.quality,
            acceptedAt: event.acceptedAt.toUtc(),
          ),
        ),
      ),
      sessions: List.unmodifiable([
        for (final session in sessions)
          LocalReviewSession(
            id: session.id,
            cards: (jsonDecode(session.cardsJson) as List)
                .map((c) => readCard(c as Map<String, dynamic>))
                .toList(),
            position: session.position,
            revealed: session.revealed,
            createdAt: session.createdAt.toUtc(),
            finishedAt: session.finishedAt?.toUtc(),
            qualities: events
                .where((e) => e.sessionId == session.id)
                .map((e) => e.quality)
                .toList(),
          ),
      ]),
    );
  }

  Future<void> start() async {
    if ((await load()).active != null) return;
    final schedules =
        await (db.select(db.localSchedules)
              ..where(
                (s) =>
                    s.active.equals(true) &
                    s.dueAt.isSmallerOrEqualValue(clock().toUtc()),
              )
              ..orderBy([
                (s) => OrderingTerm.asc(s.dueAt),
                (s) => OrderingTerm.asc(s.wordId),
              ])
              ..limit(20))
            .get();
    if (schedules.isEmpty) {
      throw const LocalDataException(
        'Chưa có từ đến hạn. Bạn có thể xem lại bộ từ đã lưu.',
      );
    }
    final cards = <Map<String, dynamic>>[];
    for (final schedule in schedules) {
      final word =
          await (db.select(db.localWords)..where(
                (w) => w.id.equals(schedule.wordId) & w.saved.equals(true),
              ))
              .getSingleOrNull();
      if (word != null) cards.add(card(word));
    }
    if (cards.isEmpty) {
      throw const LocalDataException('Bộ ôn đã thay đổi. Hãy tải lại.');
    }
    await db
        .into(db.localReviewSessions)
        .insert(
          LocalReviewSessionsCompanion.insert(
            id: const Uuid().v4(),
            cardsJson: jsonEncode(cards),
            createdAt: clock().toUtc(),
          ),
        );
  }

  Future<void> reveal(String id, int position) async {
    final session = await (db.select(
      db.localReviewSessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null ||
        session.finishedAt != null ||
        session.position != position) {
      throw const LocalConflict();
    }
    await (db.update(db.localReviewSessions)..where((s) => s.id.equals(id)))
        .write(const LocalReviewSessionsCompanion(revealed: Value(true)));
  }

  Future<void> rate(String id, int position, MemoryRating rating) async {
    final session = await (db.select(
      db.localReviewSessions,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null ||
        session.finishedAt != null ||
        session.position != position ||
        !session.revealed) {
      throw const LocalConflict();
    }
    final cards = jsonDecode(session.cardsJson) as List;
    if (position >= cards.length) throw const LocalConflict();
    final wordId = cards[position]['id'] as String;
    final now = clock().toUtc();
    await db
        .into(db.localReviewEvents)
        .insert(
          LocalReviewEventsCompanion.insert(
            id: '$id:$position',
            sessionId: id,
            wordId: wordId,
            position: position,
            quality: rating.quality,
            acceptedAt: now,
          ),
        );
    final schedule = await (db.select(
      db.localSchedules,
    )..where((s) => s.wordId.equals(wordId))).getSingleOrNull();
    // Removing/deleting a word does not destroy its immutable session/history snapshot.
    if (schedule != null && schedule.active) {
      final next = ReviewSchedule(
        repetitions: schedule.repetitions,
        intervalDays: schedule.intervalDays,
        ease: schedule.ease,
      ).next(rating);
      await (db.update(
        db.localSchedules,
      )..where((s) => s.wordId.equals(wordId))).write(
        LocalSchedulesCompanion(
          repetitions: Value(next.repetitions),
          intervalDays: Value(next.intervalDays),
          ease: Value(next.ease),
          dueAt: Value(now.add(Duration(days: next.intervalDays))),
        ),
      );
    }
    final complete = position + 1 == cards.length;
    await (db.update(
      db.localReviewSessions,
    )..where((s) => s.id.equals(id))).write(
      LocalReviewSessionsCompanion(
        position: Value(position + 1),
        revealed: const Value(false),
        finishedAt: complete ? Value(now) : const Value.absent(),
      ),
    );
  }

  Future<Map<String, dynamic>> export() async => {
    'schedules': [
      for (final r in await db.select(db.localSchedules).get())
        {
          'wordId': r.wordId,
          'n': r.repetitions,
          'interval': r.intervalDays,
          'ease': r.ease,
          'dueAt': r.dueAt.toUtc().toIso8601String(),
          'active': r.active,
        },
    ],
    'sessions': [
      for (final r in await db.select(db.localReviewSessions).get())
        {
          'id': r.id,
          'cards': jsonDecode(r.cardsJson),
          'position': r.position,
          'revealed': r.revealed,
          'createdAt': r.createdAt.toUtc().toIso8601String(),
          'finishedAt': r.finishedAt?.toUtc().toIso8601String(),
        },
    ],
    'events': [
      for (final r in await db.select(db.localReviewEvents).get())
        {
          'id': r.id,
          'sessionId': r.sessionId,
          'wordId': r.wordId,
          'position': r.position,
          'quality': r.quality,
          'acceptedAt': r.acceptedAt.toUtc().toIso8601String(),
        },
    ],
  };

  Future<void> clear() async {
    await db.delete(db.localReviewEvents).go();
    await db.delete(db.localReviewSessions).go();
    await db.delete(db.localSchedules).go();
  }

  Future<void> restore(Map<String, dynamic>? input, Map<String, bool> words) =>
      applyRestore(prepareRestore(input, words));
  Future<void> applyRestore(PreparedReviewRestore? prepared) async {
    if (prepared == null) {
      await initializeMissing();
      return;
    }
    await db.batch((b) {
      b.insertAll(db.localSchedules, prepared.schedules);
      b.insertAll(db.localReviewSessions, prepared.sessions);
      b.insertAll(db.localReviewEvents, prepared.events);
    });
  }

  PreparedReviewRestore? prepareRestore(
    Map<String, dynamic>? input,
    Map<String, bool> words,
  ) {
    if (input == null) return null;
    final prepared = PreparedReviewRestore([], [], []);
    try {
      final rawSchedules = input['schedules'] as List,
          rawSessions = input['sessions'] as List,
          rawEvents = input['events'] as List;
      if (rawSchedules.length > 10000 ||
          rawSessions.length > 10000 ||
          rawEvents.length > 200000) {
        throw const FormatException();
      }
      final scheduleIds = <String>{},
          sessions = <String, Map<String, dynamic>>{},
          positions = <String, Set<int>>{};
      for (final raw in rawSchedules) {
        final r = raw as Map<String, dynamic>;
        final id = r['wordId'] as String;
        if (!words.containsKey(id) ||
            !scheduleIds.add(id) ||
            r['active'] != words[id] ||
            r['n'] is! int ||
            r['n'] < 0 ||
            r['interval'] is! int ||
            r['interval'] < 0 ||
            r['interval'] > 1000000 ||
            r['ease'] is! num ||
            !(r['ease'] as num).isFinite ||
            r['ease'] < 1.3) {
          throw const FormatException();
        }
        prepared.schedules.add(
          LocalSchedulesCompanion.insert(
            wordId: id,
            repetitions: Value(r['n']),
            intervalDays: Value(r['interval']),
            ease: Value((r['ease'] as num).toDouble()),
            dueAt: DateTime.parse(r['dueAt']).toUtc(),
            active: Value(r['active']),
          ),
        );
      }
      for (final raw in rawSessions) {
        final r = raw as Map<String, dynamic>;
        final id = r['id'] as String, cards = r['cards'] as List;
        if (id.isEmpty ||
            id.length > 100 ||
            sessions.containsKey(id) ||
            cards.isEmpty ||
            cards.length > 20 ||
            r['position'] is! int ||
            r['position'] < 0 ||
            r['position'] > cards.length ||
            r['revealed'] is! bool ||
            ((r['position'] == cards.length) != (r['finishedAt'] != null))) {
          throw const FormatException();
        }
        final cardIds = <String>{};
        for (final card in cards) {
          if (card is! Map<String, dynamic> ||
              card['personal'] is! bool ||
              [
                'id',
                'hanzi',
                'pinyin',
                'meaning',
                'exampleHanzi',
                'exampleVietnamese',
              ].any(
                (k) => card[k] is! String || (card[k] as String).length > 2000,
              ) ||
              !cardIds.add(card['id'])) {
            throw const FormatException();
          }
          readCard(card);
        }
        sessions[id] = r;
        positions[id] = <int>{};
        prepared.sessions.add(
          LocalReviewSessionsCompanion.insert(
            id: id,
            cardsJson: jsonEncode(cards),
            position: Value(r['position']),
            revealed: Value(r['revealed']),
            createdAt: DateTime.parse(r['createdAt']).toUtc(),
            finishedAt: Value(
              r['finishedAt'] == null
                  ? null
                  : DateTime.parse(r['finishedAt']).toUtc(),
            ),
          ),
        );
      }
      for (final raw in rawEvents) {
        final r = raw as Map<String, dynamic>;
        final session = sessions[r['sessionId']];
        final position = r['position'];
        if (session == null ||
            ![0, 3, 4, 5].contains(r['quality']) ||
            r['position'] is! int ||
            r['position'] < 0 ||
            r['position'] >= session['position'] ||
            r['id'] != '${r['sessionId']}:${r['position']}' ||
            r['wordId'] != (session['cards'] as List)[r['position']]['id'] ||
            !positions[r['sessionId']]!.add(r['position'])) {
          throw const FormatException();
        }
        prepared.events.add(
          LocalReviewEventsCompanion.insert(
            id: r['id'],
            sessionId: r['sessionId'],
            wordId: r['wordId'],
            position: position,
            quality: r['quality'],
            acceptedAt: DateTime.parse(r['acceptedAt']).toUtc(),
          ),
        );
      }
      if (sessions.entries.any(
        (e) => positions[e.key]!.length != e.value['position'],
      )) {
        throw const FormatException();
      }
      if (words.entries.any((e) => e.value && !scheduleIds.contains(e.key))) {
        throw const FormatException();
      }
      return prepared;
    } catch (error) {
      if (error is LocalDataException) rethrow;
      throw const LocalDataException(
        'Lịch hoặc lịch sử ôn trong backup không hợp lệ; dữ liệu hiện có vẫn giữ.',
      );
    }
  }
}

class PreparedReviewRestore {
  PreparedReviewRestore(this.schedules, this.sessions, this.events);
  final List<LocalSchedulesCompanion> schedules;
  final List<LocalReviewSessionsCompanion> sessions;
  final List<LocalReviewEventsCompanion> events;
}
