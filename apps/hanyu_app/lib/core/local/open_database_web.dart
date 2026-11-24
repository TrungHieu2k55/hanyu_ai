import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import 'local_database.dart';
import 'database_names.dart';

LocalDatabase openLocalDatabase() => _openDatabase(learnerDatabaseName);
LocalDatabase openAdminDatabase() => _openDatabase(adminDatabaseName);

LocalDatabase _openDatabase(String name) => LocalDatabase(
  DatabaseConnection.delayed(
    Future(() async {
      final result = await WasmDatabase.open(
        databaseName: name,
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.dart.js'),
      );
      if ((result.chosenImplementation == WasmStorageImplementation.inMemory ||
          result.chosenImplementation ==
              WasmStorageImplementation.unsafeIndexedDb)) {
        await result.resolvedExecutor.close();
        throw StateError(
          'Trình duyệt chưa cho phép lưu bền vững. Hãy bật lưu trữ hoặc dùng cửa sổ thường.',
        );
      }
      return result.resolvedExecutor;
    }),
  ),
);
