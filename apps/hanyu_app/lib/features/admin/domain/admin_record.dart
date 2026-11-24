class AdminRecord {
  AdminRecord(this.fields);
  Map<String, String> fields;
  String status = 'Nháp';
  String get title => fields.values.first;
}
