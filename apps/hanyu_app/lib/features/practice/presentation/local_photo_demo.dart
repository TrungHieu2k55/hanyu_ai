import 'package:flutter/material.dart';

import '../../../app/preview_session_store.dart';
import '../../ocr/presentation/ocr_screen.dart';

class LocalPhotoDemo extends StatefulWidget {
  const LocalPhotoDemo({super.key});

  @override
  State<LocalPhotoDemo> createState() => _LocalPhotoDemoState();
}

class _LocalPhotoDemoState extends State<LocalPhotoDemo> {
  final data = PreviewSessionStore();

  @override
  Widget build(BuildContext context) => OcrScreen(
    history: data.scanHistory,
    saved: data.saved,
    notes: data.notes,
    personalWords: data.personalWords,
    nextPersonalId: () => 'demo-${++data.personalCounter}',
    onChanged: () {},
  );
}
