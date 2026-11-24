import '../local/local_models.dart';

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const LocalDataException('Cấu trúc JSON không hợp lệ.');
  }
  return value;
}

void jsonKeys(Map<String, dynamic> data, List<String> keys) {
  if (data.length != keys.length || data.keys.any((k) => !keys.contains(k))) {
    throw const LocalDataException(
      'Thiếu trường hoặc có trường ngoài hợp đồng.',
    );
  }
}

String boundedText(Object? value, int max, {bool empty = false}) {
  if (value is! String ||
      value.trim().runes.length > max ||
      (!empty && value.trim().isEmpty)) {
    throw const LocalDataException(
      'Văn bản học liệu trống hoặc vượt giới hạn.',
    );
  }
  return value.trim();
}

int boundedInt(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const LocalDataException('Giá trị số ngoài phạm vi cho phép.');
  }
  return value;
}

String uuidValue(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(value)) {
    throw const LocalDataException('Mã nội dung phải là UUID hợp lệ.');
  }
  return value;
}

DateTime utcValue(Object? value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc || date.toIso8601String() != value) {
    throw const LocalDataException('Thời gian không theo định dạng UTC chuẩn.');
  }
  return date;
}

T enumValue<T extends Enum>(Iterable<T> values, Object? name) {
  final result = values.where((v) => v.name == name).firstOrNull;
  if (result == null) {
    throw const LocalDataException('Loại hoặc trạng thái không hợp lệ.');
  }
  return result;
}
