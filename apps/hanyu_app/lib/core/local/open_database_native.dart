import 'package:drift_flutter/drift_flutter.dart';

import 'database_names.dart';
import 'local_database.dart';

LocalDatabase openLocalDatabase() => _openDatabase(learnerDatabaseName);
LocalDatabase openAdminDatabase() => _openDatabase(adminDatabaseName);

LocalDatabase _openDatabase(String name) =>
    LocalDatabase(driftDatabase(name: name));
