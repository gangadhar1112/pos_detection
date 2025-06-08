import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;

  PosePainter(this.pose, this.imageSize);

  final Paint landmarkPaint = Paint()
    ..color = Colors.red
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round;

  final Paint linePaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 3.0;

  // Helper to scale landmarks from image to canvas size
  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw landmarks
    for (final landmark in pose.landmarks.values) {
      final point = _scalePoint(landmark, size);
      canvas.drawCircle(point, 5, landmarkPaint);
    }

    // Draw connections (lines) between landmarks
    void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
      final l1 = pose.landmarks[a];
      final l2 = pose.landmarks[b];
      if (l1 != null && l2 != null) {
        final p1 = _scalePoint(l1, size);
        final p2 = _scalePoint(l2, size);
        canvas.drawLine(p1, p2, linePaint);
      }
    }

    // Torso
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Left arm
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    // Right arm
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Left leg
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    // Right leg
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Head and neck
    drawLine(PoseLandmarkType.leftEye, PoseLandmarkType.rightEye);
    drawLine(PoseLandmarkType.leftEye, PoseLandmarkType.nose);
    drawLine(PoseLandmarkType.rightEye, PoseLandmarkType.nose);
    drawLine(PoseLandmarkType.nose, PoseLandmarkType.leftEar);
    drawLine(PoseLandmarkType.nose, PoseLandmarkType.rightEar);
    drawLine(PoseLandmarkType.leftEar, PoseLandmarkType.leftShoulder);
    drawLine(PoseLandmarkType.rightEar, PoseLandmarkType.rightShoulder);

    // You can add more lines here if you want to connect other landmarks
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
