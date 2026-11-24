import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'app/learner_shell.dart';

class HanyuApp extends StatelessWidget {
  const HanyuApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hanyu AI',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.learner,
    home: const LearnerShell(),
  );
}
