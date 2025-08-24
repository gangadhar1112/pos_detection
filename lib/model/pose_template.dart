import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';


class PoseTemplate {
  final String name;
  final String imagePath;
  final List<PoseLandmark> landmarks;  // Stored landmarks
  final Size imageSize;

  PoseTemplate({
    required this.name,
    required this.imagePath,
    required this.landmarks,
    required this.imageSize,
  });

  // Convert stored landmarks list into a Pose object
  Pose landmarksToPose() {
    final landmarkMap = <PoseLandmarkType, PoseLandmark>{};

    for (var lm in landmarks) {
      landmarkMap[lm.type] = lm;
    }

    return Pose(landmarks: landmarkMap);
  }
}

// Example extension method or inside your PoseTemplate class
extension PoseTemplateExtensions on PoseTemplate {
  /// Converts saved landmarks to a ML Kit Pose object for drawing
  Pose landmarksToPose() {
    // Create a Map<PoseLandmarkType, PoseLandmark> from your stored landmarks
    final Map<PoseLandmarkType, PoseLandmark> landmarksMap = {};

    for (final lm in landmarks) {
      // lm.type is your saved landmark type, map to PoseLandmarkType
      final type = lm.type; // make sure this is of type PoseLandmarkType

      // Create PoseLandmark with normalized coords (x,y)
      // You may need to convert from your saved coords to normalized coordinates (0-1)
      landmarksMap[type] = PoseLandmark(
        type: type,
        x: lm.x,
        y: lm.y,
        z: 0,  likelihood: 1.0,
      );
    }

    // Create and return a Pose object with these landmarks
    return Pose(landmarks: landmarksMap);
  }
}



