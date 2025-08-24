import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Lightweight, serializable landmark for storage
class StoredLandmark {
  final String type; // PoseLandmarkType as string
  final double x;
  final double y;
  final double z;
  final double likelihood;

  StoredLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.likelihood,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'x': x,
    'y': y,
    'z': z,
    'likelihood': likelihood,
  };

  factory StoredLandmark.fromJson(Map<String, dynamic> json) => StoredLandmark(
    type: json['type'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    z: (json['z'] as num).toDouble(),
    likelihood: (json['likelihood'] as num).toDouble(),
  );

  /// Convert back to ML Kit PoseLandmark
  PoseLandmark toPoseLandmark() => PoseLandmark(
    type: _typeFromString(type),
    x: x,
    y: y,
    z: z,
    likelihood: likelihood,
  );

  static PoseLandmarkType _typeFromString(String s) {
    return PoseLandmarkType.values.firstWhere(
          (e) => e.toString() == s || e.name == s,
      orElse: () => PoseLandmarkType.nose,
    );
  }

  static String typeToString(PoseLandmarkType t) => t.toString();
}

/// The saved template model
class PoseTemplate {
  final String id;
  final String name;
  final String imagePath; // preview image you captured
  final Size imageSize;
  final List<StoredLandmark> storedLandmarks;

  /// Scale-invariant pairwise distances between key joints (normalized).
  /// Key format: "leftShoulder_rightShoulder", etc.
  final Map<String, double> normalizedDistances;

  PoseTemplate({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.imageSize,
    required this.storedLandmarks,
    required this.normalizedDistances,
  });

  /// Build from a detected ML Kit Pose
  factory PoseTemplate.fromDetectedPose({
    required String id,
    required String name,
    required String imagePath,
    required Size imageSize,
    required Pose pose,
  }) {
    final landmarks = pose.landmarks.values.toList();
    final stored = landmarks
        .map((lm) => StoredLandmark(
      type: StoredLandmark.typeToString(lm.type),
      x: lm.x,
      y: lm.y,
      z: lm.z,
      likelihood: lm.likelihood,
    ))
        .toList();

    final normalized = _normalizeForDistances(landmarks);
    final distances = _calculatePairwiseNormalizedDistances(normalized);

    return PoseTemplate(
      id: id,
      name: name,
      imagePath: imagePath,
      imageSize: imageSize,
      storedLandmarks: stored,
      normalizedDistances: distances,
    );
  }

  /// Convert back to ML Kit Pose for drawing overlays, etc.
  Pose landmarksToPose() {
    // Build the Pose.landmarks Map<PoseLandmarkType, PoseLandmark>
    final map = <PoseLandmarkType, PoseLandmark>{};
    for (final sl in storedLandmarks) {
      final pl = sl.toPoseLandmark();
      map[pl.type] = pl;
    }
    // The ML Kit Pose class exposes a public constructor that accepts landmarks map.
    return Pose(landmarks: map);
  }

  /// JSON serialization
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imagePath': imagePath,
    'imageSize': {'w': imageSize.width, 'h': imageSize.height},
    'storedLandmarks': storedLandmarks.map((e) => e.toJson()).toList(),
    'normalizedDistances': normalizedDistances,
  };

  factory PoseTemplate.fromJson(Map<String, dynamic> json) => PoseTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    imagePath: json['imagePath'] as String,
    imageSize: Size(
      (json['imageSize']['w'] as num).toDouble(),
      (json['imageSize']['h'] as num).toDouble(),
    ),
    storedLandmarks: (json['storedLandmarks'] as List<dynamic>)
        .map((e) => StoredLandmark.fromJson(e as Map<String, dynamic>))
        .toList(),
    normalizedDistances:
    (json['normalizedDistances'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
  );

  String encode() => jsonEncode(toJson());
  static PoseTemplate decode(String s) => PoseTemplate.fromJson(jsonDecode(s));

  /// ============== Helpers used by ScanPosePage =================

  /// Normalize using torso center & scale (scale-invariant, more stable)
  static List<PoseLandmark> _normalizeForDistances(List<PoseLandmark> lms) {
    PoseLandmark getOr(PoseLandmarkType t, PoseLandmark fallback) =>
        lms.firstWhere((e) => e.type == t, orElse: () => fallback);

    final f = lms.first;
    final ls = getOr(PoseLandmarkType.leftShoulder, f);
    final rs = getOr(PoseLandmarkType.rightShoulder, f);
    final lh = getOr(PoseLandmarkType.leftHip, f);
    final rh = getOr(PoseLandmarkType.rightHip, f);

    final cx = (ls.x + rs.x + lh.x + rh.x) / 4;
    final cy = (ls.y + rs.y + lh.y + rh.y) / 4;

    final torsoW = (ls.x - rs.x).abs();
    final torsoH = (ls.y - lh.y).abs();
    final scale = max(1e-6, max(torsoW, torsoH));

    return lms
        .map((lm) => PoseLandmark(
      type: lm.type,
      x: (lm.x - cx) / scale,
      y: (lm.y - cy) / scale,
      z: lm.z,
      likelihood: lm.likelihood,
    ))
        .toList();
  }

  /// Calculate a small, robust set of pairwise distances (normalized coords)
  static Map<String, double> _calculatePairwiseNormalizedDistances(
      List<PoseLandmark> normalized) {
    double d(PoseLandmark a, PoseLandmark b) {
      final dx = a.x - b.x;
      final dy = a.y - b.y;
      return sqrt(dx * dx + dy * dy);
    }

    PoseLandmark get(PoseLandmarkType t, PoseLandmark fallback) =>
        normalized.firstWhere((e) => e.type == t, orElse: () => fallback);

    final f = normalized.first;

    final pairs = <String, List<PoseLandmarkType>>{
      'leftShoulder_rightShoulder': [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      'leftHip_rightHip': [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      'leftShoulder_leftHip': [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      'rightShoulder_rightHip': [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      'leftElbow_leftWrist': [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      'rightElbow_rightWrist': [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      'leftKnee_leftAnkle': [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      'rightKnee_rightAnkle': [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    };

    final out = <String, double>{};
    pairs.forEach((key, value) {
      final a = get(value[0], f);
      final b = get(value[1], f);
      out[key] = d(a, b);
    });
    return out;
  }

  /// For live pose comparison (called from ScanPosePage)
  static Map<String, double> calculateDistances(List<PoseLandmark> landmarks) {
    final norm = _normalizeForDistances(landmarks);
    return _calculatePairwiseNormalizedDistances(norm);
  }
}
