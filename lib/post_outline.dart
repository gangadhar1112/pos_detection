import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseOutlinePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color lineColor;

  PoseOutlinePainter({
    required this.pose,
    required this.imageSize,
    this.lineColor = Colors.white,
  });

  final Paint linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;

  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  void _drawLine(Canvas canvas, Size size, PoseLandmarkType a, PoseLandmarkType b) {
    final l1 = pose.landmarks[a];
    final l2 = pose.landmarks[b];
    if (l1 != null && l2 != null) {
      final p1 = _scalePoint(l1, size);
      final p2 = _scalePoint(l2, size);
      canvas.drawLine(p1, p2, linePaint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw pose connections without dots:

    // Torso
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    _drawLine(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    _drawLine(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // Left arm
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    _drawLine(canvas, size, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    // Right arm
    _drawLine(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    _drawLine(canvas, size, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // Left leg
    _drawLine(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    _drawLine(canvas, size, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    // Right leg
    _drawLine(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    _drawLine(canvas, size, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // Head & Neck
    _drawLine(canvas, size, PoseLandmarkType.leftEye, PoseLandmarkType.rightEye);
    _drawLine(canvas, size, PoseLandmarkType.leftEye, PoseLandmarkType.nose);
    _drawLine(canvas, size, PoseLandmarkType.rightEye, PoseLandmarkType.nose);
    _drawLine(canvas, size, PoseLandmarkType.nose, PoseLandmarkType.leftEar);
    _drawLine(canvas, size, PoseLandmarkType.nose, PoseLandmarkType.rightEar);
    _drawLine(canvas, size, PoseLandmarkType.leftEar, PoseLandmarkType.leftShoulder);
    _drawLine(canvas, size, PoseLandmarkType.rightEar, PoseLandmarkType.rightShoulder);
  }

  @override
  bool shouldRepaint(covariant PoseOutlinePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
