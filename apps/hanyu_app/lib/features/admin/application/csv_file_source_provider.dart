import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/csv_file_source.dart';

final csvFileSourceProvider = Provider<CsvFileSource>(
  (ref) => const LocalCsvFileSource(),
);
