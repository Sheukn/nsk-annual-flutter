import 'package:flutter/material.dart';

abstract class DrawingAction {
  void draw(Canvas canvas);
}

class StrokeAction extends DrawingAction {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  StrokeAction(this.points, this.color, this.strokeWidth);

  @override
  void draw(Canvas canvas) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }
}

class CircleAction extends DrawingAction {
  final Offset center;
  final double radius;
  final Color color;
  final double strokeWidth;

  CircleAction(this.center, this.radius, this.color, this.strokeWidth);

  @override
  void draw(Canvas canvas) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, paint);
  }
}

class SquareAction extends DrawingAction {
  final Offset topLeft;
  final double width;
  final double height;
  final Color color;
  final double strokeWidth;

  SquareAction(
    this.topLeft,
    this.width,
    this.height,
    this.color,
    this.strokeWidth,
  );

  @override
  void draw(Canvas canvas) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
      paint,
    );
  }
}
