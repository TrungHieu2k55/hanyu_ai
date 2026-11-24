import 'package:drift/drift.dart';

part 'local_database.g.dart';

@DataClassName('StoredWord')
class LocalWords extends Table {
  TextColumn get id => text()();
  TextColumn get hanzi => text()();
  TextColumn get pinyin => text()();
  TextColumn get meaning => text()();
  TextColumn get exampleHanzi => text().withDefault(const Constant(''))();
  TextColumn get exampleVietnamese => text().withDefault(const Constant(''))();
  BoolColumn get personal => boolean()();
  BoolColumn get saved => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

class LocalMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class LocalReceipts extends Table {
  TextColumn get operationId => text()();
  TextColumn get fingerprint => text()();
  @override
  Set<Column> get primaryKey => {operationId};
}

@DataClassName('StoredSchedule')
class LocalSchedules extends Table {
  TextColumn get wordId =>
      text().references(LocalWords, #id, onDelete: KeyAction.cascade)();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  DateTimeColumn get dueAt => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {wordId};
}

@DataClassName('StoredReviewSession')
class LocalReviewSessions extends Table {
  TextColumn get id => text()();
  TextColumn get cardsJson => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  BoolColumn get revealed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredReviewEvent')
class LocalReviewEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(
    LocalReviewSessions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get wordId => text()();
  IntColumn get position => integer()();
  IntColumn get quality => integer()();
  DateTimeColumn get acceptedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredExamAttempt')
class LocalExamAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get packageId => text()();
  TextColumn get packageVersion => text()();
  IntColumn get targetLevel => integer()();
  TextColumn get mode => text()();
  TextColumn get questionsJson => text()();
  TextColumn get answersJson => text().withDefault(const Constant('{}'))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get deadline => dateTime()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  BoolColumn get timedOut => boolean().withDefault(const Constant(false))();
  IntColumn get correctCount => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredPracticeEntry')
class LocalPracticeEntries extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get dataJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('StoredMedia')
class LocalMedia extends Table {
  TextColumn get id => text()();
  TextColumn get mime => text()();
  BlobColumn get bytes => blob()();
  TextColumn get checksum => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

// E stores immutable contract snapshots. Domain stores validate JSON before SQL.
class LocalFeedbackReports extends Table {
  TextColumn get id => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  TextColumn get dataJson => text()();
  TextColumn get state => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id, revision};
}

@TableIndex.sql(
  "CREATE UNIQUE INDEX local_admin_current_published ON local_admin_revisions (item_id) WHERE state = 'published'",
)
class LocalAdminRevisions extends Table {
  TextColumn get itemId => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  TextColumn get kind => text()();
  TextColumn get dataJson => text()();
  TextColumn get state => text()();
  BoolColumn get exported => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {itemId, revision};
}

class LocalAdminInbox extends Table {
  TextColumn get reportId => text()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  TextColumn get reportJson => text()();
  TextColumn get status => text()();
  TextColumn get receiptJson => text().nullable()();
  DateTimeColumn get receivedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {reportId, revision};
}

class LocalAdminPackages extends Table {
  TextColumn get packageId => text()();
  IntColumn get version =>
      integer().customConstraint('NOT NULL CHECK (version > 0)')();
  BlobColumn get bytes => blob()();
  TextColumn get checksum => text()();
  @override
  Set<Column> get primaryKey => {packageId, version};
}

class LocalInstalledPackages extends Table {
  TextColumn get packageId => text()();
  TextColumn get publisherId => text()();
  IntColumn get version =>
      integer().customConstraint('NOT NULL CHECK (version > 0)')();
  TextColumn get dataJson => text()();
  TextColumn get checksum => text()();
  @override
  Set<Column> get primaryKey => {packageId};
}

class LocalCatalogReceipts extends Table {
  TextColumn get publisherId => text()();
  TextColumn get packageId => text()();
  IntColumn get version =>
      integer().customConstraint('NOT NULL CHECK (version > 0)')();
  TextColumn get checksum => text()();
  @override
  Set<Column> get primaryKey => {publisherId, packageId, version};
}

@DriftDatabase(
  tables: [
    LocalWords,
    LocalMetadata,
    LocalReceipts,
    LocalSchedules,
    LocalReviewSessions,
    LocalReviewEvents,
    LocalExamAttempts,
    LocalPracticeEntries,
    LocalMedia,
    LocalFeedbackReports,
    LocalAdminRevisions,
    LocalAdminInbox,
    LocalAdminPackages,
    LocalInstalledPackages,
    LocalCatalogReceipts,
  ],
)
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.executor);
  @override
  int get schemaVersion => 5;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 1 || from >= to || to != 5) {
        throw StateError(
          'No verified migration path from $from to $to. Database kept intact.',
        );
      }
      if (from < 2) {
        await m.createTable(localSchedules);
        await m.createTable(localReviewSessions);
        await m.createTable(localReviewEvents);
      }
      if (from < 3) await m.createTable(localExamAttempts);
      if (from < 4) {
        await m.createTable(localPracticeEntries);
        await m.createTable(localMedia);
      }
      if (from < 5) {
        await m.createTable(localFeedbackReports);
        await m.createTable(localAdminRevisions);
        await m.createTable(localAdminInbox);
        await m.createTable(localAdminPackages);
        await m.createTable(localInstalledPackages);
        await m.createTable(localCatalogReceipts);
        await m.createIndex(localAdminCurrentPublished);
      }
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}
