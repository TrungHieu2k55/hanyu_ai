import 'package:flutter/material.dart';

import '../ui_tokens.dart';
import 'figma_icon.dart';

/// Keeps icons on one baseline while destination labels wrap independently.
class LearnerNavigationBar extends StatelessWidget {
  const LearnerNavigationBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.bottom = true,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool bottom;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      bottom: bottom,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, label) in labels.indexed)
                Expanded(
                  child: _Destination(
                    glyph: learnerNavigationGlyphs[index],
                    label: label,
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final FigmaGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? brandTeal : mutedText;
    // Keep five tab labels readable on a narrow screen at maximum system text.
    final labelScaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: 1.5);
    return Semantics(
      container: true,
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Column(
              children: [
                Ink(
                  width: 64,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? softSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: FigmaIcon(glyph, color: color),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  textScaler: labelScaler,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(height: 1.2, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
