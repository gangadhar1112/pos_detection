import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class RealisticPosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;

  RealisticPosePainter({
    required this.pose,
    required this.imageSize,
  });

  final Paint fillPaint = Paint()
    ..color = Colors.blue.withOpacity(0.3)
    ..style = PaintingStyle.fill;

  final Paint strokePaint = Paint()
    ..color = Colors.blue
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke;

  Offset _scalePoint(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  void _drawLimb(Canvas canvas, Size size, PoseLandmarkType from, PoseLandmarkType to) {
    final l1 = pose.landmarks[from];
    final l2 = pose.landmarks[to];
    if (l1 != null && l2 != null) {
      final p1 = _scalePoint(l1, size);
      final p2 = _scalePoint(l2, size);
      canvas.drawLine(p1, p2, strokePaint);
    }
  }

  void _drawOvalPart(Canvas canvas, Size size, PoseLandmarkType centerType, PoseLandmarkType refType, double factor) {
    final center = pose.landmarks[centerType];
    final ref = pose.landmarks[refType];
    if (center != null && ref != null) {
      final c = _scalePoint(center, size);
      final r = _scalePoint(ref, size);
      final radius = (r - c).distance * factor;
      canvas.drawOval(Rect.fromCircle(center: c, radius: radius), fillPaint);
    }
  }

  void _drawHead(Canvas canvas, Size size) {
    _drawOvalPart(canvas, size, PoseLandmarkType.nose, PoseLandmarkType.leftEye, 1.5);
  }

  void _drawTorso(Canvas canvas, Size size) {
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lh = pose.landmarks[PoseLandmarkType.leftHip];
    final rh = pose.landmarks[PoseLandmarkType.rightHip];

    if (ls != null && rs != null && lh != null && rh != null) {
      final p1 = _scalePoint(ls, size);
      final p2 = _scalePoint(rs, size);
      final p3 = _scalePoint(rh, size);
      final p4 = _scalePoint(lh, size);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();
      canvas.drawPath(path, fillPaint);
    }
  }

  void _drawHand(Canvas canvas, Size size, PoseLandmarkType wrist, PoseLandmarkType pinky) {
    _drawOvalPart(canvas, size, wrist, pinky, 0.6);
  }

  void _drawFoot(Canvas canvas, Size size, PoseLandmarkType ankle, PoseLandmarkType footIndex) {
    _drawOvalPart(canvas, size, ankle, footIndex, 0.8);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawHead(canvas, size);
    _drawTorso(canvas, size);

    // Arms
    _drawLimb(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    _drawLimb(canvas, size, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    _drawHand(canvas, size, PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky);

    _drawLimb(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    _drawLimb(canvas, size, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    _drawHand(canvas, size, PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky);

    // Legs
    _drawLimb(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    _drawLimb(canvas, size, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    _drawFoot(canvas, size, PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex);

    _drawLimb(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    _drawLimb(canvas, size, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    _drawFoot(canvas, size, PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex);
  }

  @override
  bool shouldRepaint(covariant RealisticPosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}