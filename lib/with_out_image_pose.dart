import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class WithoutBackgroundPose extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color color;

  WithoutBackgroundPose({
    required this.pose,
    required this.imageSize,
    this.color = Colors.blue,
  });

  final Paint linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = Colors.blue;

  final Paint fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = Colors.blue.withOpacity(0.3);

  Offset _scale(PoseLandmark landmark, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    return Offset(landmark.x * scaleX, landmark.y * scaleY);
  }

  void _drawDebugElbows(Canvas canvas, Size size) {
    final left = pose.landmarks[PoseLandmarkType.leftElbow];
    final right = pose.landmarks[PoseLandmarkType.rightElbow];

    if (left != null) {
      final p = _scale(left, size);
      canvas.drawCircle(p, 10, Paint()..color = Colors.red);
    }
    if (right != null) {
      final p = _scale(right, size);
      canvas.drawCircle(p, 10, Paint()..color = Colors.green);
    }
  }

  void _drawHead(Canvas canvas, Size size) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rightEye = pose.landmarks[PoseLandmarkType.rightEye];

    if (nose != null && leftEye != null && rightEye != null) {
      final center = _scale(nose, size);
      final eyeL = _scale(leftEye, size);
      final eyeR = _scale(rightEye, size);
      final width = (eyeR.dx - eyeL.dx).abs() * 2;
      final height = width * 1.3;

      final rect = Rect.fromCenter(center: center, width: width, height: height);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color;

      canvas.drawOval(rect, paint);
    }
  }

  void _drawHand(Canvas canvas, Size size, PoseLandmarkType wrist, List<PoseLandmarkType> fingers) {
    final wristLandmark = pose.landmarks[wrist];
    if (wristLandmark == null) return;

    final points = <Offset>[];
    points.add(_scale(wristLandmark, size));

    for (var finger in fingers) {
      final fingerLandmark = pose.landmarks[finger];
      if (fingerLandmark != null) {
        points.add(_scale(fingerLandmark, size));
      }
    }

    if (points.length > 2) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawBody(Canvas canvas, Size size) {
    final landmarks = pose.landmarks;
    final points = [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftHip,
    ].map((e) => landmarks[e]).whereType<PoseLandmark>().map((l) => _scale(l, size)).toList();

    if (points.length == 4) {
      final path = Path()
        ..moveTo(points[0].dx, points[0].dy)
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(points[2].dx, points[2].dy)
        ..lineTo(points[3].dx, points[3].dy)
        ..close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawLeg(Canvas canvas, Size size, PoseLandmarkType hip, PoseLandmarkType knee,
      PoseLandmarkType ankle, PoseLandmarkType heel, PoseLandmarkType footIndex) {
    final landmarks = pose.landmarks;
    final points = [
      landmarks[hip],
      landmarks[knee],
      landmarks[ankle],
      landmarks[heel],
      landmarks[footIndex],
    ].whereType<PoseLandmark>().map((l) => _scale(l, size)).toList();

    if (points.length == 5) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawArm(Canvas canvas, Size size, PoseLandmarkType shoulder, PoseLandmarkType elbow,
      PoseLandmarkType wrist, List<PoseLandmarkType> fingers) {
    final landmarks = pose.landmarks;
    final s = landmarks[shoulder];
    final e = landmarks[elbow];
    final w = landmarks[wrist];

    if (s == null || e == null || w == null) return;

    final points = [_scale(s, size), _scale(e, size), _scale(w, size)];

    final fingerPoints = fingers
        .map((f) => landmarks[f])
        .whereType<PoseLandmark>()
        .map((l) => _scale(l, size))
        .toList();

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var pt in points.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    for (var pt in fingerPoints) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  void _drawAllLandmarks(Canvas canvas, Size size) {
    pose.landmarks.forEach((type, landmark) {
      final pos = _scale(landmark, size);
      canvas.drawCircle(pos, 4, Paint()..color = Colors.orange);
      final textPainter = TextPainter(
        text: TextSpan(
          text: type.name,
          style: TextStyle(color: Colors.black, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, pos + Offset(5, 5));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.landmarks.isEmpty) return;

    //_drawAllLandmarks(canvas, size); // Optional: for debugging

    //_drawDebugElbows(canvas, size);  // Red = left, Green = right

    _drawHead(canvas, size);

    _drawBody(canvas, size);

    _drawArm(canvas, size, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist, [PoseLandmarkType.leftThumb, PoseLandmarkType.leftPinky]);

    _drawArm(canvas, size, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist, [PoseLandmarkType.rightThumb, PoseLandmarkType.rightPinky]);

    _drawHand(canvas, size, PoseLandmarkType.leftWrist, [PoseLandmarkType.leftThumb]);
    _drawHand(canvas, size, PoseLandmarkType.rightWrist, [PoseLandmarkType.rightThumb]);

    _drawLeg(canvas, size, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex);

    _drawLeg(canvas, size, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex);
  }

  @override
  bool shouldRepaint(covariant WithoutBackgroundPose oldDelegate) =>
      oldDelegate.pose != pose || oldDelegate.imageSize != imageSize;
}