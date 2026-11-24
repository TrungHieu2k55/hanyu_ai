import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/ui_tokens.dart';

// Self-authored normalized illustration for UI, not Hanzi Writer/model data.
const samplePersonStrokes = [
  [Offset(.54, .18), Offset(.50, .38), Offset(.39, .62), Offset(.20, .82)],
  [Offset(.50, .40), Offset(.60, .63), Offset(.78, .83)],
];

class StrokeIllustrationPainter extends CustomPainter {
  const StrokeIllustrationPainter({
    required this.active,
    this.progress = 1,
    this.faint = false,
  });
  final int active;
  final double progress;
  final bool faint;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < samplePersonStrokes.length; i++) {
      final points = samplePersonStrokes[i];
      final path = Path()
        ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 7
        ..color = brandTeal.withValues(
          alpha: faint
              ? .22
              : i == active
              ? 1
              : .18,
        );
      if (i == active) {
        for (final metric in path.computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * progress), pen);
        }
      } else {
        canvas.drawPath(path, pen);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StrokeIllustrationPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.progress != progress ||
      oldDelegate.faint != faint;
}
