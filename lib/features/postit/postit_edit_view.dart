import 'package:flutter/material.dart';
import 'models/drawing_action.dart';
import 'models/drawing_tool.dart';
import 'painters/drawing_painter.dart';
import 'widgets/color_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class PostItEditView extends StatefulWidget {
  const PostItEditView({super.key, required this.id});
  final String id;
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

  double _getCanvasSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 32.0; // 16px padding on each side
    return screenWidth - padding;
  }

  Offset clampOffset(Offset offset, double canvasSize) {
    return Offset(offset.dx.clamp(0.0, canvasSize), offset.dy.clamp(0.0, canvasSize));
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

  final GlobalKey _globalKey = GlobalKey();

  void _saveAndReturn() async {
    String filePath = await savePostItAsImage();
    debugPrint("Image saved at: $filePath");
    if (mounted) {
      Navigator.of(context).pop({
        'imagePath': filePath, 
        'actions': actions.sublist(0, currentIndex + 1), 
        'canvasColor': canvasColor,
      });
    }
  }

  Future<String> savePostItAsImage() async {
  try {
      RenderRepaintBoundary boundary = 
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) throw Exception("Erreur lors de la capture");
      
      Uint8List pngBytes = byteData.buffer.asUint8List();

      return await saveImageToCache(pngBytes);
    } catch (e) {
      debugPrint("Erreur sauvegarde image: $e");
      return "";
    }
  }

  Future<String> saveImageToCache(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final String fileName = "postit_${widget.id}.png";
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Post-it Editor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        actions: [
          IconButton(
            onPressed: () {
              _saveAndReturn();
            },
            icon: const Icon(Icons.save),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                clearCanvas();
              });
            },
            icon: const Icon(Icons.clear),
          ),
          IconButton(
            onPressed: () {
              undo();
            },
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            onPressed: () {
              redo();
            },
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onPanStart: (details) {
                final canvasSize = _getCanvasSize(context);
                setState(() {
                  currentStroke = [clampOffset(details.localPosition, canvasSize)];
                });
              },
              onPanUpdate: (details) {
                final canvasSize = _getCanvasSize(context);
                setState(() {
                  final clampedPosition = clampOffset(details.localPosition, canvasSize);
                  if (currentTool == DrawingTool.pen ||
                      currentTool == DrawingTool.eraser) {
                    currentStroke.add(clampedPosition);
                  }
                });
              },
              onPanEnd: (details) {
                if (currentStroke.isNotEmpty) {
                  setState(() {
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
                  });
                }
              },
              child: Container(
                width: _getCanvasSize(context),
                height: _getCanvasSize(context),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child: ClipRect(
                  child: RepaintBoundary(
                    key: _globalKey,  
                    child: CustomPaint(
                      painter: DrawingPainter(
                        actions: actions,
                        currentStroke: currentStroke,
                        currentIndex: currentIndex,
                        currentTool: currentTool,
                        currentColor: currentColor,
                        canvasColor: canvasColor,
                      ),
                      size: Size(_getCanvasSize(context), _getCanvasSize(context)),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolButton(
                icon: Icons.color_lens,
                label: 'Color',
                isSelected: false,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
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
                backgroundColor: currentColor,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (strokeSize > 1) strokeSize--;
                        });
                      },
                      child: const Icon(Icons.remove, size: 18, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$strokeSize',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (strokeSize < 20) strokeSize++;
                        });
                      },
                      child: const Icon(Icons.add, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToolButton(
                icon: Icons.brush,
                label: 'Pen',
                isSelected: currentTool == DrawingTool.pen,
                onPressed: () {
                  setState(() {
                    currentTool = DrawingTool.pen;
                  });
                },
              ),
              const SizedBox(width: 8),
              _buildToolButton(
                icon: Icons.cleaning_services,
                label: 'Eraser',
                isSelected: currentTool == DrawingTool.eraser,
                onPressed: () {
                  setState(() {
                    currentTool = DrawingTool.eraser;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: backgroundColor ?? (isSelected ? Colors.blue : Colors.grey.shade700),
          size: 24,
        ),
      ),
    );
  }
}
