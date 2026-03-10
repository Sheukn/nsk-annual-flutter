import 'package:flutter/material.dart';
import '../constants/board_constants.dart';

class RotationSlider extends StatelessWidget {
  final double rotation;
  final Function(double) onChanged;

  const RotationSlider({
    super.key,
    required this.rotation,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 1),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rotate_right, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            SizedBox(
              height: 200,
              width: 40,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: rotation,
                  min: -pi,
                  max: pi,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.white24,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SizeSlider extends StatelessWidget {
  final double width;
  final Function(double) onChanged;

  const SizeSlider({super.key, required this.width, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 1),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.aspect_ratio, color: Colors.white, size: 20),
            SizedBox(
              height: 200,
              width: 40,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: width,
                  min: 50,
                  max: 500,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.white24,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
