class CsvImportProblem implements Exception {
  const CsvImportProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

class CsvRecord {
  const CsvRecord(this.number, this.cells);
  final int number;
  final List<String> cells;
}

class CsvTable {
  const CsvTable(this.headers, this.records);
  final List<String> headers;
  final List<CsvRecord> records;
}

class VocabularyColumnMapping {
  const VocabularyColumnMapping({
    required this.hanzi,
    required this.pinyin,
    required this.vietnamese,
  });
  final int hanzi, pinyin, vietnamese;
  List<int> get indices => [hanzi, pinyin, vietnamese];
}

class VocabularyDraft {
  const VocabularyDraft(this.hanzi, this.pinyin, this.vietnamese);
  final String hanzi, pinyin, vietnamese;
}

enum ImportIssueCode {
  columns,
  required,
  hanzi,
  duplicateInFile,
  duplicateExisting,
  limit,
}

class ImportIssue {
  const ImportIssue(this.record, this.field, this.message, this.code);
  final int record;
  final String field, message;
  final ImportIssueCode code;
}

class VocabularyImportReport {
  const VocabularyImportReport(this.drafts, this.issues);
  final List<VocabularyDraft> drafts;
  final List<ImportIssue> issues;
  int get rejectedRecords => issues.map((issue) => issue.record).toSet().length;
}
