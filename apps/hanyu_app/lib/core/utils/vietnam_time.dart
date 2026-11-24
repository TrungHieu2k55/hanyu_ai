String formatVietnamTime(DateTime utc) {
  final time = utc.toUtc().add(const Duration(hours: 7));
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(time.day)}/${pad(time.month)}/${time.year} ${pad(time.hour)}:${pad(time.minute)}';
}
