import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SimplePosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color lineColor;

  SimplePosePainter({
    required this.pose,
    required this.imageSize,
    this.lineColor = Colors.blue,
  });

  final Paint linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;

  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  void _drawLine(Canvas canvas, Size size, PoseLandmarkType from, PoseLandmarkType to) {
    final l1 = pose.landmarks[from];
    final l2 = pose.landmarks[to];
    if (l1 != null && l2 != null) {
      final p1 = _scalePoint(l1, size);
      final p2 = _scalePoint(l2, size);
      canvas.drawLine(p1, p2, linePaint..color = lineColor);
    }
  }

  void _drawCircle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // HEAD circle based on nose & eyes
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (nose != null && leftEye != null && rightEye != null) {
      final c = _scalePoint(nose, size);
      final eyeL = _scalePoint(leftEye, size);
      final eyeR = _scalePoint(rightEye, size);
      final radius = (eyeR - eyeL).distance * 1.8;
      _drawCircle(canvas, c, radius);
    }

    // TORSO: Shoulders -> Hips
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    _drawLine(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    _drawLine(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

    // LEFT ARM
    _drawLine(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    _drawLine(canvas, size, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    _drawLine(canvas, size, PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb);
    _drawLine(canvas, size, PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex);
    _drawLine(canvas, size, PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky);

    // RIGHT ARM
    _drawLine(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    _drawLine(canvas, size, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    _drawLine(canvas, size, PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb);
    _drawLine(canvas, size, PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex);
    _drawLine(canvas, size, PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky);

    // LEFT LEG
    _drawLine(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    _drawLine(canvas, size, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    _drawLine(canvas, size, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel);
    _drawLine(canvas, size, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex);

    // RIGHT LEG
    _drawLine(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    _drawLine(canvas, size, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    _drawLine(canvas, size, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel);
    _drawLine(canvas, size, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex);
  }

  @override
  bool shouldRepaint(covariant SimplePosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
