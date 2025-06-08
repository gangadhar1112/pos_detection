import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class RealisticBodyOutlinePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color color;

  RealisticBodyOutlinePainter({
    required this.pose,
    required this.imageSize,
    this.color = Colors.blue,
  });

  final Paint outlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..color = Colors.blueAccent;

  final Paint fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.blueAccent.withOpacity(0.25);

  Offset _scale(PoseLandmark lm, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(lm.x * scaleX, lm.y * scaleY);
  }

  Offset _perpendicular(Offset v) {
    return Offset(-v.dy, v.dx);
  }

  Offset _normalize(Offset v) {
    final len = v.distance;
    return len == 0 ? Offset.zero : v / len;
  }

  Path _createLimbOutline(Offset start, Offset end, double thickness) {
    final direction = end - start;
    final perp = _normalize(_perpendicular(direction));

    final p1 = start + perp * thickness;
    final p2 = end + perp * thickness;
    final p3 = end - perp * thickness;
    final p4 = start - perp * thickness;

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..quadraticBezierTo(
          (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2, p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..quadraticBezierTo(
          (p3.dx + p4.dx) / 2, (p3.dy + p4.dy) / 2, p4.dx, p4.dy)
      ..close();

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lm = pose.landmarks;

    // Check for necessary points before drawing
    if (lm.isEmpty) return;

    // Scale all key points
    Offset ls = _scale(lm[PoseLandmarkType.leftShoulder]!, size);
    Offset rs = _scale(lm[PoseLandmarkType.rightShoulder]!, size);
    Offset lh = _scale(lm[PoseLandmarkType.leftHip]!, size);
    Offset rh = _scale(lm[PoseLandmarkType.rightHip]!, size);

    Offset le = _scale(lm[PoseLandmarkType.leftElbow]!, size);
    Offset re = _scale(lm[PoseLandmarkType.rightElbow]!, size);

    Offset lw = _scale(lm[PoseLandmarkType.leftWrist]!, size);
    Offset rw = _scale(lm[PoseLandmarkType.rightWrist]!, size);

    Offset lk = _scale(lm[PoseLandmarkType.leftKnee]!, size);
    Offset rk = _scale(lm[PoseLandmarkType.rightKnee]!, size);

    Offset la = _scale(lm[PoseLandmarkType.leftAnkle]!, size);
    Offset ra = _scale(lm[PoseLandmarkType.rightAnkle]!, size);

    // Torso polygon (shoulders + hips)
    final torsoPath = Path()
      ..moveTo(ls.dx, ls.dy)
      ..lineTo(rs.dx, rs.dy)
      ..lineTo(rh.dx, rh.dy)
      ..lineTo(lh.dx, lh.dy)
      ..close();

    canvas.drawPath(torsoPath, fillPaint);
    canvas.drawPath(torsoPath, outlinePaint);

    // Arms outlines
    double armThickness = 20;
    final leftUpperArm = _createLimbOutline(ls, le, armThickness);
    final leftLowerArm = _createLimbOutline(le, lw, armThickness * 0.8);
    final rightUpperArm = _createLimbOutline(rs, re, armThickness);
    final rightLowerArm = _createLimbOutline(re, rw, armThickness * 0.8);

    canvas.drawPath(leftUpperArm, fillPaint);
    canvas.drawPath(leftUpperArm, outlinePaint);

    canvas.drawPath(leftLowerArm, fillPaint);
    canvas.drawPath(leftLowerArm, outlinePaint);

    canvas.drawPath(rightUpperArm, fillPaint);
    canvas.drawPath(rightUpperArm, outlinePaint);

    canvas.drawPath(rightLowerArm, fillPaint);
    canvas.drawPath(rightLowerArm, outlinePaint);

    // Legs outlines
    double legThickness = 25;
    final leftUpperLeg = _createLimbOutline(lh, lk, legThickness);
    final leftLowerLeg = _createLimbOutline(lk, la, legThickness * 0.9);
    final rightUpperLeg = _createLimbOutline(rh, rk, legThickness);
    final rightLowerLeg = _createLimbOutline(rk, ra, legThickness * 0.9);

    canvas.drawPath(leftUpperLeg, fillPaint);
    canvas.drawPath(leftUpperLeg, outlinePaint);

    canvas.drawPath(leftLowerLeg, fillPaint);
    canvas.drawPath(leftLowerLeg, outlinePaint);

    canvas.drawPath(rightUpperLeg, fillPaint);
    canvas.drawPath(rightUpperLeg, outlinePaint);

    canvas.drawPath(rightLowerLeg, fillPaint);
    canvas.drawPath(rightLowerLeg, outlinePaint);

    // Head ellipse around nose
    final nose = lm[PoseLandmarkType.nose];
    final leftEye = lm[PoseLandmarkType.leftEye];
    final rightEye = lm[PoseLandmarkType.rightEye];
    if (nose != null && leftEye != null && rightEye != null) {
      final c = _scale(nose, size);
      final eyeLeft = _scale(leftEye, size);
      final eyeRight = _scale(rightEye, size);

      final w = (eyeRight.dx - eyeLeft.dx).abs() * 2.2;
      final h = w * 1.4;
      final headRect = Rect.fromCenter(center: c, width: w, height: h);

      canvas.drawOval(headRect, fillPaint);
      canvas.drawOval(headRect, outlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant RealisticBodyOutlinePainter oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
}
