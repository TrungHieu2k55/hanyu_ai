import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'presentation/local_admin_inbox.dart';

class LocalAdminApp extends StatelessWidget {
  const LocalAdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hanyu AI · Admin local',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const LocalAdminInboxScreen(),
  );
}
