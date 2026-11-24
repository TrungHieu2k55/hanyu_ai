class ScanRecord {
  final createdAt = DateTime.now().toUtc();
  ScanRecord(this.number, this.rawText) : editedText = rawText;
  final int number;
  final String rawText;
  String editedText;
  bool hasImage = true;
}
