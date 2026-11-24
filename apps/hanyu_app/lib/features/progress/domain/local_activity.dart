class LocalActivity {
  const LocalActivity(
    this.kind,
    this.title,
    this.detail,
    this.createdAt,
    this.onOpen,
  );
  final String kind, title, detail;
  final DateTime createdAt;
  final Future<void> Function() onOpen;
}
