import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class QuestionChoices extends StatelessWidget {
  const QuestionChoices({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });
  final List<String> choices;
  final int? selected;
  final ValueChanged<int> onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < choices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.all(16),
              backgroundColor: selected == i ? softSurface : Colors.white,
            ),
            onPressed: enabled ? () => onSelected(i) : null,
            icon: Icon(
              selected == i
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            label: Text(choices[i]),
          ),
        ),
    ],
  );
}
