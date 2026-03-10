import 'package:flutter/material.dart';
import '../models/drawing_action.dart';
import '../models/drawing_tool.dart';

class DrawingPainter extends CustomPainter {
  final List<DrawingAction> actions;
  final List<Offset> currentStroke;
  final int currentIndex;
  final DrawingTool currentTool;
  final Color currentColor;
  final Color canvasColor;

  DrawingPainter({
    required this.actions,
    required this.currentStroke,
    required this.currentIndex,
    required this.currentTool,
    required this.currentColor,
    required this.canvasColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = canvasColor;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    for (int i = 0; i <= currentIndex && i < actions.length; i++) {
      actions[i].draw(canvas);
    }

    if (currentStroke.length > 1) {
      final paint =
          Paint()
            ..color = currentTool == DrawingTool.eraser ? bgColor : currentColor
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round;

      if (currentTool == DrawingTool.pen || currentTool == DrawingTool.eraser) {
        paint.style = PaintingStyle.stroke;
        for (int i = 0; i < currentStroke.length - 1; i++) {
          canvas.drawLine(currentStroke[i], currentStroke[i + 1], paint);
        }
      } else if (currentTool == DrawingTool.circle) {
        final center = currentStroke.first;
        final radius = (currentStroke.last - center).distance;
        paint.style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius, paint);
      } else if (currentTool == DrawingTool.square) {
        final topLeft = Offset(
          currentStroke.first.dx < currentStroke.last.dx
              ? currentStroke.first.dx
              : currentStroke.last.dx,
          currentStroke.first.dy < currentStroke.last.dy
              ? currentStroke.first.dy
              : currentStroke.last.dy,
        );
        final width = (currentStroke.last.dx - currentStroke.first.dx).abs();
        final height = (currentStroke.last.dy - currentStroke.first.dy).abs();
        paint.style = PaintingStyle.stroke;
        canvas.drawRect(
          Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
