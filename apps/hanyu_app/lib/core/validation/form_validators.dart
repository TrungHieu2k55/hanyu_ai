abstract final class FormValidators {
  static String? email(String? value) =>
      value != null &&
          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
      ? null
      : 'Nhập email đúng định dạng.';
  static String? password(String? value) =>
      (value?.length ?? 0) >= 8 ? null : 'Nhập ít nhất 8 ký tự.';
  static String? confirmation(String? value, String expected) =>
      value == null || value.isEmpty || value != expected
      ? 'Hai mật khẩu chưa khớp.'
      : null;
}
