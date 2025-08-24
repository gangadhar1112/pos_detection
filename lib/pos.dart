import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final Pose? pose;
  final Size imageSize;
  final bool drawConnections;

  PosePainter({required this.pose, required this.imageSize, this.drawConnections = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (pose == null) return;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill
      ..strokeWidth = 4;

    // Flip scaleX/Y if needed depending on your camera feed orientation
    double scaleX = size.width / imageSize.width;
    double scaleY = size.height / imageSize.height;

    // Draw landmarks as circles
    for (final landmark in pose!.landmarks.values) {
      final offset = Offset(landmark.x * scaleX, landmark.y * scaleY);
      canvas.drawCircle(offset, 6, paint);
    }

    if (drawConnections) {
      final connectionPaint = Paint()
        ..color = Colors.lightBlueAccent
        ..strokeWidth = 2;

      final connections = [
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
        [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
        [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
        [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
        [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
        [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
        [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
        [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
        [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
        [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      ];

      for (final connection in connections) {
        final start = pose!.landmarks[connection[0]];
        final end = pose!.landmarks[connection[1]];
        if (start != null && end != null) {
          final p1 = Offset(start.x * scaleX, start.y * scaleY);
          final p2 = Offset(end.x * scaleX, end.y * scaleY);
          canvas.drawLine(p1, p2, connectionPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}
