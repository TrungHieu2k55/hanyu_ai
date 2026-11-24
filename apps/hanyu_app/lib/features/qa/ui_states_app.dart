import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/core/theme/app_theme.dart';
import 'package:doanchuyennganh2/features/qa/presentation/states_gallery.dart';

class HanyuUiStatesPreview extends StatelessWidget {
  const HanyuUiStatesPreview({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hanyu AI · UI States',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.learner,
    home: const StatesGallery(),
  );
}
