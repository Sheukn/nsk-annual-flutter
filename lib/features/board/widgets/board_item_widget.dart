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
      content = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey.shade300,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade600, size: 40),
            const SizedBox(height: 8),
            Text(
              'Tap to pick image',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    } else {
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
        child: Transform.scale(
          scale: item.scale,
          child: Transform.rotate(
            angle: item.rotation,
            child: Container(
              width: item.size.width,
              height: item.size.height,
              decoration: BoxDecoration(
                color: item.color,
                border: isSelected 
                  ? Border.all(color: Colors.blue, width: 3) 
                  : Border.all(color: Colors.grey.shade300, width: 1),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: Colors.blue.withAlpha(120),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
