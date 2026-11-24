import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/admin/presentation/preview_admin_workspace.dart';

class HanyuAdminPreview extends StatelessWidget {
  const HanyuAdminPreview({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hanyu AI · Admin mẫu',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const PreviewAdminWorkspace(),
  );
}
