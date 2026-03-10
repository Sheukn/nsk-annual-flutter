import 'package:flutter/material.dart';
import 'models/drawing_action.dart';
import 'models/drawing_tool.dart';
import 'painters/drawing_painter.dart';
import 'widgets/color_picker.dart';

class PostItEditView extends StatefulWidget {
  const PostItEditView({super.key});

  @override
  State<PostItEditView> createState() => _PostItEditViewState();
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
