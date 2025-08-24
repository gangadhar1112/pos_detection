import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;   // raw camera image size
  final Size widgetSize;  // preview widget size
  final bool isFrontCamera;

  PosePainter({
    required this.pose,
    required this.imageSize,
    required this.widgetSize,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.fill;

    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    for (final landmark in pose.landmarks.values) {
      double dx = landmark.x * scaleX;
      double dy = landmark.y * scaleY;

      // Mirror horizontally if front camera
      if (isFrontCamera) {
        dx = widgetSize.width - dx;
      }

      canvas.drawCircle(Offset(dx, dy), 6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
