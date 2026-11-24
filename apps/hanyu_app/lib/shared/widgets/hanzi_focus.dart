import 'package:flutter/material.dart';

import '../ui_tokens.dart';

/// A proportional writing grid behind dynamic text, with a text-only reflow for
/// long headwords or large system text.
class HanziFocus extends StatelessWidget {
  const HanziFocus(this.text, {this.dark = false, this.size = 56, super.key});
  final String text;
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final count = text.runes.length;
    final scaled = MediaQuery.textScalerOf(context).scale(size);
    final useGrid = count > 0 && count <= 2 && scaled <= size * 1.2;
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : brandInk,
      ),
    );
    if (!useGrid) return label;
    return CustomPaint(
      painter: _GridPainter(count, dark),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: label,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.columns, this.dark);
  final int columns;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / columns;
    final guide = Paint()
      ..color = dark ? const Color(0xFF4A7A7D) : const Color(0xFF9BC8C2);
    for (var i = 0; i < columns; i++) {
      final rect = Rect.fromLTWH(
        i * cellWidth + 1,
        1,
        cellWidth - 2,
        size.height - 2,
      );
      final frame = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      if (!dark) canvas.drawRRect(frame, Paint()..color = softSurface);
      guide.style = PaintingStyle.stroke;
      canvas.drawRRect(frame, guide);
      guide.style = PaintingStyle.fill;
      canvas.drawLine(
        Offset(rect.center.dx, rect.top + 4),
        Offset(rect.center.dx, rect.bottom - 4),
        guide,
      );
      canvas.drawLine(
        Offset(rect.left + 4, rect.center.dy),
        Offset(rect.right - 4, rect.center.dy),
        guide,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      columns != oldDelegate.columns || dark != oldDelegate.dark;
}
