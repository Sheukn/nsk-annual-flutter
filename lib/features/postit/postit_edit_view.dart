import 'package:flutter/material.dart';

class PostItEditView extends StatefulWidget {
  const PostItEditView({super.key});
  @override
  State<PostItEditView> createState() => _PostItEditViewState();
}

enum DrawingTool { pen, eraser, circle, square }

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

class _PostItEditViewState extends State<PostItEditView> {
  DrawingTool currentTool = DrawingTool.pen;
  List<DrawingAction> actions = [];
  List<Offset> currentStroke = [];
  int currentIndex = -1;
  int strokeSize = 3;
  Color currentColor = Colors.black;
  Color canvasColor = Colors.white;

  Offset clampOffset(Offset offset) {
    return Offset(offset.dx.clamp(0.0, 500.0), offset.dy.clamp(0.0, 500.0));
  }

  void clearCanvas() {
    setState(() {
      actions.clear();
      currentStroke.clear();
      currentIndex = -1;
    });
  }

  void undo() {
    if (currentIndex >= 0) {
      setState(() {
        currentIndex--;
      });
    }
  }

  void redo() {
    if (currentIndex < actions.length - 1) {
      setState(() {
        currentIndex++;
      });
    }
  }

  void _saveAndReturn() {
    // Return the post-it data to the board
    Navigator.of(context).pop({
      'actions': actions.sublist(0, currentIndex + 1),
      'canvasColor': canvasColor,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post-it Editor'),
        actions: [
          IconButton(
            onPressed: () {
              _saveAndReturn();
            },
            icon: const Icon(Icons.save),
            tooltip: 'Save as Post-it',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                clearCanvas();
              });
            },
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
          ),
          IconButton(
            onPressed: () {
              undo();
            },
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: () {
              redo();
            },
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onPanStart: (details) {
                setState(() {
                  currentStroke = [clampOffset(details.localPosition)];
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  final clampedPosition = clampOffset(details.localPosition);
                  if (currentTool == DrawingTool.pen ||
                      currentTool == DrawingTool.eraser) {
                    currentStroke.add(clampedPosition);
                  } else if (currentTool == DrawingTool.circle ||
                      currentTool == DrawingTool.square) {
                    currentStroke = [currentStroke.first, clampedPosition];
                  }
                });
              },
              onPanEnd: (details) {
                if (currentStroke.isNotEmpty) {
                  setState(() {
                    if (currentTool == DrawingTool.pen ||
                        currentTool == DrawingTool.eraser) {
                      actions = actions.sublist(0, currentIndex + 1);
                      actions.add(
                        StrokeAction(
                          List.from(currentStroke),
                          currentTool == DrawingTool.eraser
                              ? canvasColor
                              : currentColor,
                          strokeSize.toDouble(),
                        ),
                      );
                      currentIndex++;
                    } else if (currentTool == DrawingTool.circle) {
                      final center = currentStroke.first;
                      final radius = (currentStroke.last - center).distance;
                      actions = actions.sublist(0, currentIndex + 1);
                      actions.add(
                        CircleAction(
                          center,
                          radius,
                          currentColor,
                          strokeSize.toDouble(),
                        ),
                      );
                      currentIndex++;
                    } else if (currentTool == DrawingTool.square) {
                      final topLeft = Offset(
                        currentStroke.first.dx < currentStroke.last.dx
                            ? currentStroke.first.dx
                            : currentStroke.last.dx,
                        currentStroke.first.dy < currentStroke.last.dy
                            ? currentStroke.first.dy
                            : currentStroke.last.dy,
                      );
                      final width =
                          (currentStroke.last.dx - currentStroke.first.dx)
                              .abs();
                      final height =
                          (currentStroke.last.dy - currentStroke.first.dy)
                              .abs();

                      actions = actions.sublist(0, currentIndex + 1);
                      actions.add(
                        SquareAction(
                          topLeft,
                          width,
                          height,
                          currentColor,
                          strokeSize.toDouble(),
                        ),
                      );
                      currentIndex++;
                    }
                  });
                }
              },
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: ClipRect(
                  child: CustomPaint(
                    painter: DrawingPainter(
                      actions: actions,
                      currentStroke: currentStroke,
                      currentIndex: currentIndex,
                      currentTool: currentTool,
                      currentColor: currentColor,
                      canvasColor: canvasColor,
                    ),
                    size: const Size(500, 500),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildBackgroundColorMenu(),
            const SizedBox(height: 8),
            _buildToolMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundColorMenu() {
    final colors = [
      Colors.white,
      Colors.yellow.shade100,
      Colors.pink.shade100,
      Colors.blue.shade100,
      Colors.green.shade100,
      Colors.orange.shade100,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.palette, size: 20, color: Colors.grey),
          ),
          ...colors.map((color) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  canvasColor = color;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        canvasColor == color
                            ? Colors.blue
                            : Colors.grey.shade400,
                    width: canvasColor == color ? 3 : 1,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildToolMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.lightGreen,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Select Color'),
                      content: ColorPicker(
                        currentColor: currentColor,
                        onColorSelected: (color) {
                          setState(() {
                            currentColor = color;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
              );
            },
            icon: Icon(Icons.color_lens, color: currentColor),
            tooltip: 'Color Picker',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                currentTool = DrawingTool.pen;
              });
            },
            icon: const Icon(Icons.brush),
            tooltip: 'Pen',
            color: currentTool == DrawingTool.pen ? Colors.blue : Colors.grey,
          ),
          IconButton(
            onPressed: () {
              setState(() {
                currentTool = DrawingTool.circle;
              });
            },
            icon: const Icon(Icons.circle_outlined),
            tooltip: 'Circle',
            color:
                currentTool == DrawingTool.circle ? Colors.blue : Colors.grey,
          ),
          IconButton(
            onPressed: () {
              setState(() {
                currentTool = DrawingTool.square;
              });
            },
            icon: const Icon(Icons.crop_square),
            tooltip: 'Square',
            color:
                currentTool == DrawingTool.square ? Colors.blue : Colors.grey,
          ),
          IconButton(
            onPressed: () {
              setState(() {
                currentTool = DrawingTool.eraser;
              });
            },
            icon: const Icon(Icons.cleaning_services),
            tooltip: 'Eraser',
            color:
                currentTool == DrawingTool.eraser ? Colors.blue : Colors.grey,
          ),
        ],
      ),
    );
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

class ColorPicker extends StatelessWidget {
  final Color currentColor;
  final Function(Color) onColorSelected;

  const ColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _colorOption(Colors.black),
        _colorOption(Colors.red),
        _colorOption(Colors.green),
        _colorOption(Colors.blue),
        _colorOption(Colors.yellow),
        _colorOption(Colors.white),
      ],
    );
  }

  Widget _colorOption(Color color) {
    return GestureDetector(
      onTap: () => onColorSelected(color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: currentColor == color ? Colors.blue : Colors.transparent,
            width: 2.0,
          ),
        ),
      ),
    );
  }
}
