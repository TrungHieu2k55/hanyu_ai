import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:doanchuyennganh2/shared/widgets/writing_grid_painter.dart';

/// Captures normalized points; grading/recognition belongs outside the widget.
class HandwritingPad extends StatefulWidget {
  const HandwritingPad({
    required this.strokes,
    required this.onStart,
    required this.onUpdate,
    this.onEnd,
    this.overlay,
    this.enabled = true,
    super.key,
  });
  final List<List<Offset>> strokes;
  final ValueChanged<Offset> onStart, onUpdate;
  final VoidCallback? onEnd;
  final CustomPainter? overlay;
  final bool enabled;
  @override
  State<HandwritingPad> createState() => _HandwritingPadState();
}

class _HandwritingPadState extends State<HandwritingPad> {
  int? pointer;
  Offset normalize(Offset value, double width) => Offset(
    (value.dx / width).clamp(0.0, 1.0),
    (value.dy / width).clamp(0.0, 1.0),
  );
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (_, box) {
            final picture = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: WritingGridPainter(widget.strokes),
                foregroundPainter: widget.overlay,
                child: const SizedBox.expand(),
              ),
            );
            if (!widget.enabled) return picture;
            return RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                EagerGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      EagerGestureRecognizer
                    >(() => EagerGestureRecognizer(), (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (pointer != null) return;
                  pointer = event.pointer;
                  widget.onStart(normalize(event.localPosition, box.maxWidth));
                },
                onPointerMove: (event) {
                  if (pointer == event.pointer) {
                    widget.onUpdate(
                      normalize(event.localPosition, box.maxWidth),
                    );
                  }
                },
                onPointerUp: (event) {
                  if (pointer == event.pointer) {
                    pointer = null;
                    widget.onEnd?.call();
                  }
                },
                onPointerCancel: (event) {
                  if (pointer == event.pointer) {
                    pointer = null;
                    widget.onEnd?.call();
                  }
                },
                child: picture,
              ),
            );
          },
        ),
      ),
    ),
  );
}
