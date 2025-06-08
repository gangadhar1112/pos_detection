import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class ReferencePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color lineColor;

  ReferencePainter({
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

  void _drawCircle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawFilledCircle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawPolygon(Canvas canvas, List<Offset> points, Color color) {
    if (points.length < 3) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;
    canvas.drawPath(path, paint);
  }

  void _drawHead(Canvas canvas, Size size) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (nose != null && leftEye != null && rightEye != null) {
      final center = _scalePoint(nose, size);
      final eyeL = _scalePoint(leftEye, size);
      final eyeR = _scalePoint(rightEye, size);

      // Approximate head shape as an ellipse around nose and eyes
      final radiusX = (eyeR.dx - eyeL.dx).abs() * 1.6;
      final radiusY = radiusX * 1.3;

      final rect = Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2);
      final paint = Paint()
        ..color = Colors.orange.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect, paint);

      // Optional: draw ellipse border
      final borderPaint = Paint()
        ..color = Colors.orange.shade900
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawOval(rect, borderPaint);
    }
  }

  void _drawBody(Canvas canvas, Size size) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if ([leftShoulder, rightShoulder, leftHip, rightHip].any((e) => e == null)) return;

    final points = [
      _scalePoint(leftShoulder!, size),
      _scalePoint(rightShoulder!, size),
      _scalePoint(rightHip!, size),
      _scalePoint(leftHip!, size),
    ];

    _drawPolygon(canvas, points, Colors.blue.withOpacity(0.6));

    // Optional: outline
    final outlinePaint = Paint()
      ..color = Colors.blue.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();
    canvas.drawPath(path, outlinePaint);
  }

  void _drawArm(Canvas canvas, Size size, PoseLandmarkType shoulder, PoseLandmarkType elbow,
      PoseLandmarkType wrist, List<PoseLandmarkType> fingers) {
    final s = pose.landmarks[shoulder];
    final e = pose.landmarks[elbow];
    final w = pose.landmarks[wrist];
    if ([s, e, w].any((p) => p == null)) return;

    final pS = _scalePoint(s!, size);
    final pE = _scalePoint(e!, size);
    final pW = _scalePoint(w!, size);

    // Draw arm polygon (triangle)
    _drawPolygon(canvas, [pS, pE, pW], Colors.green.withOpacity(0.6));

    // Outline
    final outlinePaint = Paint()
      ..color = Colors.green.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..moveTo(pS.dx, pS.dy)..lineTo(pE.dx, pE.dy)..lineTo(pW.dx, pW.dy)..close();
    canvas.drawPath(path, outlinePaint);

    // Draw fingers as small circles
    for (final finger in fingers) {
      final f = pose.landmarks[finger];
      if (f != null) {
        final pF = _scalePoint(f, size);
        _drawFilledCircle(canvas, pF, 7, Colors.green.shade900);
      }
    }

    // Draw elbow as red circle
    _drawFilledCircle(canvas, pE, 10, Colors.red);
  }

  void _drawLeg(Canvas canvas, Size size, PoseLandmarkType hip, PoseLandmarkType knee,
      PoseLandmarkType ankle, PoseLandmarkType heel, PoseLandmarkType footIndex) {
    final h = pose.landmarks[hip];
    final k = pose.landmarks[knee];
    final a = pose.landmarks[ankle];
    final he = pose.landmarks[heel];
    final f = pose.landmarks[footIndex];
    if ([h, k, a, he, f].any((p) => p == null)) return;

    final pH = _scalePoint(h!, size);
    final pK = _scalePoint(k!, size);
    final pA = _scalePoint(a!, size);
    final pHe = _scalePoint(he!, size);
    final pF = _scalePoint(f!, size);

    // Draw leg polygon (trapezoid + foot shape)
    final path = Path()
      ..moveTo(pH.dx, pH.dy)
      ..lineTo(pK.dx, pK.dy)
      ..lineTo(pA.dx, pA.dy)
      ..lineTo(pHe.dx, pHe.dy)
      ..lineTo(pF.dx, pF.dy)
      ..close();

    final paint = Paint()..color = Colors.purple.withOpacity(0.6);
    canvas.drawPath(path, paint);

    final outlinePaint = Paint()
      ..color = Colors.purple.shade900
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, outlinePaint);

    // Draw knee as red circle
    _drawFilledCircle(canvas, pK, 10, Colors.red);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawHead(canvas, size);
    _drawBody(canvas, size);

    _drawArm(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist, [
          PoseLandmarkType.leftThumb,
          PoseLandmarkType.leftPinky,
        ]);

    _drawArm(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist, [
          PoseLandmarkType.rightThumb,
          PoseLandmarkType.rightPinky,
        ]);

    _drawLeg(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex);

    _drawLeg(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex);
  }

  @override
  bool shouldRepaint(covariant ReferencePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
  }
}
