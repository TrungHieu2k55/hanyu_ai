import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Stable object-key ordering; array ordering remains meaningful.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));
String canonicalChecksum(Object? value) =>
    sha256.convert(utf8.encode(canonicalJson(value))).toString();
Object? _sorted(Object? value) => switch (value) {
  Map<String, dynamic>() => {
    for (final key in value.keys.toList()..sort()) key: _sorted(value[key]),
  },
  List() => value.map(_sorted).toList(),
  _ => value,
};
