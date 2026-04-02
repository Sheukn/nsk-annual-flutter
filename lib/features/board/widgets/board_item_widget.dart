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

    if (item.isImage && item.imagePath != null && File(item.imagePath!).existsSync()) {
      content = Image.file(
        File(item.imagePath!),
        fit: BoxFit.cover,
      );
    } else if (item.isImage) {
      // Placeholder shown before a gallery image is picked.
      content = Container(
        color: const Color(0xFF2C2C2C),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: Colors.white54, size: 36),
            SizedBox(height: 6),
            Text(
              'Tap to pick image',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      );
    } else {
      // Post-it or other item with an explicit imagePath (e.g. postit PNG).
      if (item.imagePath != null && File(item.imagePath!).existsSync()) {
        content = Image.file(File(item.imagePath!), fit: BoxFit.contain);
      } else {
        content = Center(
          child: Text(item.id.toString(), style: const TextStyle(color: Colors.white)),
        );
      }
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
