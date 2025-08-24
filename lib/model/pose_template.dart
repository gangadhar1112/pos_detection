import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseTemplate {
  final String name;
  final String imagePath;
  final Size imageSize;
  final List<PoseLandmark> landmarks;

  PoseTemplate({
    required this.name,
    required this.imagePath,
    required this.imageSize,
    required this.landmarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imagePath': imagePath,
      'imageSize': {'width': imageSize.width, 'height': imageSize.height},
      'landmarks': landmarks
          .map(
            (lm) => {
              'type': lm.type.index,
              'x': lm.x,
              'y': lm.y,
              'z': lm.z,
              'likelihood': lm.likelihood,
            },
          )
          .toList(),
    };
  }

  factory PoseTemplate.fromJson(Map<String, dynamic> json) {
    final List<dynamic> landmarksJson = json['landmarks'];
    final landmarks = landmarksJson.map((lm) {
      return PoseLandmark(
        type: PoseLandmarkType.values[lm['type']],
        x: lm['x'],
        y: lm['y'],
        z: lm['z'],
        likelihood: lm['likelihood'],
      );
    }).toList();

    return PoseTemplate(
      name: json['name'],
      imagePath: json['imagePath'],
      imageSize: Size(json['imageSize']['width'], json['imageSize']['height']),
      landmarks: landmarks,
    );
  }

  Pose landmarksToPose() {
    final map = {for (var lm in landmarks) lm.type: lm};
    return Pose(landmarks: map);
  }
}
