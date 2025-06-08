import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BodyPainter extends CustomPainter {
  final Pose pose;

  BodyPainter(this.pose);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw landmarks and skeleton if needed
    _drawBodySize(canvas, size, pose); // 👈 Call your method here
  }

  void _drawBodySize(Canvas canvas, Size size, Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    if (leftShoulder != null && leftAnkle != null) {
      final start = Offset(leftShoulder.x, leftShoulder.y);
      final end = Offset(leftAnkle.x, leftAnkle.y);
      final length = (start - end).distance.toStringAsFixed(1);

      final paint = Paint()
        ..color = Colors.green
        ..strokeWidth = 3;

      canvas.drawLine(start, end, paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$length px',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(start.dx + 5, start.dy - 20));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
