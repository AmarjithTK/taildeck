import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle border.
///
/// Flutter has no dashed `BorderSide`, and the "unconfigured" card and the
/// "Add Service" card are specified as dashed in `docs/UI_SPEC.md` §2.3-2.4.
class DashedRRectBorder extends StatelessWidget {
  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 18,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRRectPainter(
      color: color,
      radius: radius,
      dash: dash,
      gap: gap,
      strokeWidth: strokeWidth,
    ),
    child: child,
  );
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Inset by half the stroke so the dashes sit fully inside the box.
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      (size.width - strokeWidth).clamp(0, size.width),
      (size.height - strokeWidth).clamp(0, size.height),
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.strokeWidth != strokeWidth;
}
