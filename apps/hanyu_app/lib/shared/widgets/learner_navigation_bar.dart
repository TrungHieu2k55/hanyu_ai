import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui_tokens.dart';
import 'figma_icon.dart';

/// Keeps destination icons aligned while labels follow system text scaling.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelStyle = Theme.of(context).textTheme.labelMedium!
              .copyWith(height: 1.2);
          const horizontalInset = 2.0;
          final labelWidth =
              constraints.maxWidth / labels.length - 2 * horizontalInset;
          final painter = TextPainter(
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          );
          final inheritedStyle = DefaultTextStyle.of(context).style;
          var labelHeight = 0.0;
          for (final label in labels) {
            painter.text = TextSpan(
              text: label,
              style: inheritedStyle.merge(labelStyle),
            );
            painter.layout(maxWidth: labelWidth);
            labelHeight = math.max(labelHeight, painter.height);
          }
          painter.dispose();
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, label) in labels.indexed)
                    Expanded(
                      child: _Destination(
                        glyph: learnerNavigationGlyphs[index],
                        label: label,
                        labelStyle: labelStyle,
                        labelHeight: labelHeight,
                        horizontalInset: horizontalInset,
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
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
    required this.labelStyle,
    required this.labelHeight,
    required this.horizontalInset,
  });

  final FigmaGlyph glyph;
  final String label;
  final TextStyle labelStyle;
  final double labelHeight;
  final double horizontalInset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? brandTeal : mutedText;
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
            padding: EdgeInsets.symmetric(
              horizontal: horizontalInset,
              vertical: 3,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Ink(
                  width: 64,
                  height: 28,
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
                SizedBox(
                  height: labelHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: labelStyle.copyWith(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
