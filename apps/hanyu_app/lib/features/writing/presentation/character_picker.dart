import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/features/writing/data/writing_samples.dart';

Future<String?> showCharacterPicker(BuildContext context) => showDialog<String>(
  context: context,
  builder: (dialog) => SimpleDialog(
    title: const Text('Chọn chữ thủ công'),
    children: [
      for (final word in writingSamples)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialog, word.$1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('${word.$1} · ${word.$2} · ${word.$3}'),
          ),
        ),
    ],
  ),
);
