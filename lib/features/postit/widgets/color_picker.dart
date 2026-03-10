import 'package:flutter/material.dart';

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
