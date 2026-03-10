import 'package:flutter/material.dart';

class BoardItem {
  final String id;
  Color color;
  Position position;
  Size size;
  double rotation = 0.0;

  BoardItem({
    required this.id,
    required this.color,
    required this.position,
    required this.size,
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
