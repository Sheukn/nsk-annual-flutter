import 'package:flutter/material.dart';

class BoardItem {
  final String id;
  Color color;
  Position position;
  Size size;
  double rotation;
  bool isImage;
  Color? backgroundColor;
  String? imagePath;

  BoardItem({
    required this.id,
    required this.color,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.isImage = false,
    this.backgroundColor,
    this.imagePath,
  });
}

class Position {
  double x;
  double y;

  Position({required this.x, required this.y});
}

class Size {
  double width;
  double height;

  Size({required this.width, required this.height});
}
