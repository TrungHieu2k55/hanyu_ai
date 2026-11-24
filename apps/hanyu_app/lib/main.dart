import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app/local/local_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const mode = String.fromEnvironment('APP_MODE', defaultValue: 'local');
  runApp(
    mode == 'preview'
        ? const HanyuApp()
        : const ProviderScope(child: LocalHanyuApp()),
  );
}
