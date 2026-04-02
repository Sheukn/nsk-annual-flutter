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
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 156, 164, 172),
              Colors.blue.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rotate_right, color: Colors.white, size: 16),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              width: 12,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: rotation,
                  min: -pi,
                  max: pi,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class SizeSlider extends StatelessWidget {
  final double scale;
  final Function(double) onChanged;

  const SizeSlider({super.key, required this.scale, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
       margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 156, 164, 172),
              Colors.blue.shade400,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.aspect_ratio, color: Colors.white, size: 16),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              width: 12,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: scale,
                  min: 0.1,
                  max: 2.5,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white24,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
