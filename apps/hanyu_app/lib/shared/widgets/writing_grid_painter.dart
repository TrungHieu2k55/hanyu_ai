import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

class WritingGridPainter extends CustomPainter {
  WritingGridPainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final line = Paint()
      ..color = const Color(0xFFCEDFDF)
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(.5, .5, size.width - 1, size.height - 1),
      Paint()
        ..color = brandTeal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      line,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      line,
    );
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), line);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), line);
    final pen = Paint()
      ..color = brandTeal
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          stroke.first * size.width,
          3,
          Paint()..color = brandTeal,
        );
        continue;
      }
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant WritingGridPainter oldDelegate) => true;
}
