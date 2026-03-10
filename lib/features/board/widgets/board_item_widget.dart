import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

class BoardItemWidget extends StatelessWidget {
  final BoardItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(ScaleStartDetails) onScaleStart;
  final Function(ScaleUpdateDetails) onScaleUpdate;

  const BoardItemWidget({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (item.imagePath != null && File(item.imagePath!).existsSync()) {
      debugPrint("Loading image from path: ${item.imagePath}");
      content = Image.file(
        File(item.imagePath!),
        fit: BoxFit.contain, 
      );
    } else {
      debugPrint("No valid image found at path: ${item.imagePath}, displaying placeholder");
      debugPrint("Item details - ID: ${item.id}, isImage: ${item.isImage}, imagePath: ${item.imagePath}");
      content = Center(
        child: Text(item.id.toString(), style: const TextStyle(color: Colors.white)),
      );
    }
    return Positioned(
      left: item.position.x,
      top: item.position.y,
      child: GestureDetector(
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Transform.rotate(
          angle: item.rotation,
          child: Container(
            width: item.size.width,
            height: item.size.height,
            decoration: BoxDecoration(
              color: item.color,
              border:
                  isSelected ? Border.all(color: Colors.blue, width: 3) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
