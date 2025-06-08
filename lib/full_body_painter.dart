import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class FullBodyShapePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;

  FullBodyShapePainter({required this.pose, required this.imageSize});

  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  Paint get _paint => Paint()
    ..color = Colors.blueAccent.withOpacity(0.7)
    ..style = PaintingStyle.fill;

  void _drawOvalHead(Canvas canvas, Size size) {
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftEar != null && rightEar != null && nose != null) {
      final left = _scalePoint(leftEar, size);
      final right = _scalePoint(rightEar, size);
      final center = _scalePoint(nose, size);
      final width = (right - left).distance * 1.2;
      final height = width * 1.4;

      final rect = Rect.fromCenter(center: center, width: width, height: height);
      canvas.drawOval(rect, _paint);
    }
  }

  void _drawTorso(Canvas canvas, Size size) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftShoulder != null && rightShoulder != null && leftHip != null && rightHip != null) {
      final points = [
        _scalePoint(leftShoulder, size),
        _scalePoint(rightShoulder, size),
        _scalePoint(rightHip, size),
        _scalePoint(leftHip, size),
      ];
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, _paint);
    }
  }

  void _drawLimb(Canvas canvas, Size size, PoseLandmarkType startType, PoseLandmarkType endType, double widthFactor) {
    final start = pose.landmarks[startType];
    final end = pose.landmarks[endType];

    if (start != null && end != null) {
      final p1 = _scalePoint(start, size);
      final p2 = _scalePoint(end, size);
      final direction = (p2 - p1).direction;
      final dx = widthFactor * 10 * imageSize.width / size.width;
      final dy = widthFactor * 10 * imageSize.height / size.height;

      final perp = Offset(-dy, dx).direction;
      final offset = Offset.fromDirection(perp, 6.0);

      final path = Path()
        ..moveTo(p1.dx + offset.dx, p1.dy + offset.dy)
        ..lineTo(p1.dx - offset.dx, p1.dy - offset.dy)
        ..lineTo(p2.dx - offset.dx, p2.dy - offset.dy)
        ..lineTo(p2.dx + offset.dx, p2.dy + offset.dy)
        ..close();

      canvas.drawPath(path, _paint);
    }
  }

  void _drawCirclePart(Canvas canvas, Size size, PoseLandmarkType type, double radius) {
    final part = pose.landmarks[type];
    if (part != null) {
      final center = _scalePoint(part, size);
      canvas.drawCircle(center, radius, _paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawOvalHead(canvas, size);
    _drawTorso(canvas, size);

    // Arms
    _drawLimb(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, 0.7);
    _drawLimb(canvas, size, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, 0.6);
    _drawCirclePart(canvas, size, PoseLandmarkType.leftWrist, 10); // Left hand

    _drawLimb(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, 0.7);
    _drawLimb(canvas, size, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, 0.6);
    _drawCirclePart(canvas, size, PoseLandmarkType.rightWrist, 10); // Right hand

    // Legs
    _drawLimb(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, 0.8);
    _drawLimb(canvas, size, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, 0.7);
    _drawCirclePart(canvas, size, PoseLandmarkType.leftAnkle, 12); // Left foot

    _drawLimb(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, 0.8);
    _drawLimb(canvas, size, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, 0.7);
    _drawCirclePart(canvas, size, PoseLandmarkType.rightAnkle, 12); // Right foot
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
