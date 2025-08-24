import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class WithoutBackgroundPose extends CustomPainter {
  final Pose pose;
  final Size imageSize;

  WithoutBackgroundPose({
    required this.pose,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.landmarks.isEmpty) return;

    // Scale from image coords → canvas coords
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;

    final pointPaint = Paint()
      ..color = Colors.redAccent   // 🔹 set color to blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    void drawPoint(PoseLandmarkType t) {
      final lm = pose.landmarks[t];
      if (lm == null) return;
      canvas.drawCircle(Offset(lm.x * sx, lm.y * sy), 3, pointPaint);
    }

    void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
      final la = pose.landmarks[a];
      final lb = pose.landmarks[b];
      if (la == null || lb == null) return;
      canvas.drawLine(
        Offset(la.x * sx, la.y * sy),
        Offset(lb.x * sx, lb.y * sy),
        pointPaint,
      );
    }

    // points
    for (final lm in pose.landmarks.values) {
      canvas.drawCircle(Offset(lm.x * sx, lm.y * sy), 2, pointPaint);
    }

    // a minimal skeleton (add more if you like)
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);

    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant WithoutBackgroundPose oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
