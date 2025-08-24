import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'model/pose_template.dart';
import 'with_out_image_pose.dart';

class ScanPosePage extends StatefulWidget {
  final PoseTemplate template;

  const ScanPosePage({required this.template, super.key});

  @override
  State<ScanPosePage> createState() => _ScanPosePageState();
}

class _ScanPosePageState extends State<ScanPosePage> {
  CameraController? _controller;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  bool _poseMatched = false;
  bool _hasCaptured = false;

  String _suggestion = '';
  Pose? _currentPose;

  double _avgPosDistance = 0.0;
  double _posMatchRatio = 0.0;
  double _distMatchRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _startCamera();
  }

  /// Initialize camera and start pose detection stream
  Future<void> _startCamera() async {
    final cameras = await availableCameras();
    final controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await controller.initialize();
    await controller.startImageStream(_processCameraImage);

    if (mounted) setState(() => _controller = controller);
  }

  /// Convert raw CameraImage -> InputImage for MLKit
  InputImage _convertCameraImage(CameraImage image, int rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final inputRotation =
        InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: inputRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  /// Camera frame → Pose Detection → Compare with Template
  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _controller == null || _poseDetector == null || _hasCaptured) return;
    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(
        image,
        _controller!.description.sensorOrientation,
      );

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final detectedPose = poses.first;
        final result = _compareWithTemplate(detectedPose, widget.template);

        setState(() {
          _currentPose = detectedPose;
          _poseMatched = result['matched'] as bool;
          _suggestion = result['suggestion'] as String;
          _avgPosDistance = result['avgDistance'] as double;
          _posMatchRatio = result['matchRatio'] as double;
          _distMatchRatio = result['distanceMatchRatio'] as double;
        });

        /// Auto-capture when pose matches
        if (_poseMatched && !_hasCaptured) {
          _hasCaptured = true;
          await _controller?.stopImageStream();
          final picture = await _controller?.takePicture();
          if (picture != null) {
            await _showCapturedPoseDialog(picture.path);
          }
        }
      } else {
        setState(() {
          _currentPose = null;
          _poseMatched = false;
          _suggestion = 'No pose detected';
          _avgPosDistance = 0;
          _posMatchRatio = 0;
          _distMatchRatio = 0;
        });
      }
    } catch (e) {
      if (kDebugMode) print('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  /// Pose comparison (position + distance similarity)
  Map<String, dynamic> _compareWithTemplate(Pose detected, PoseTemplate template) {
    // position-based
    const double perLandmarkThreshold = 0.12; // tolerance
    const double posMatchRatioThreshold = 0.75;

    // distance-based
    const double distanceDiffThreshold = 0.15;
    const double distanceMatchRatioThreshold = 0.70;

    final templateLms = template.landmarksToPose().landmarks.values.toList();
    final detectedLms = detected.landmarks.values.toList();

    final normalizedTemplate = _normalizeLandmarks(templateLms);
    final normalizedDetected = _normalizeLandmarks(detectedLms);

    final detectedMap = {for (var lm in normalizedDetected) lm.type: lm};

    int matchedCount = 0;
    int totalCount = 0;
    double totalDistance = 0;
    int comparedCount = 0;

    for (final tLm in normalizedTemplate) {
      final dLm = detectedMap[tLm.type];
      if (dLm == null) continue;

      final dx = tLm.x - dLm.x;
      final dy = tLm.y - dLm.y;
      final dist = sqrt(dx * dx + dy * dy);

      totalDistance += dist;
      comparedCount++;

      if (dist <= perLandmarkThreshold) matchedCount++;
      totalCount++;
    }

    final posMatchRatio = totalCount > 0 ? matchedCount / totalCount : 0.0;
    final avgDistance = comparedCount > 0 ? totalDistance / comparedCount : double.infinity;

    // --- Distance-based (scale-invariant)
    final liveDistances = PoseTemplate.calculateDistances(detectedLms);
    int distMatches = 0;

    template.normalizedDistances.forEach((key, savedDist) {
      final live = liveDistances[key];
      if (live == null) return;
      final diff = (savedDist - live).abs() / (savedDist.abs() + 1e-6);
      if (diff < distanceDiffThreshold) distMatches++;
    });

    final distMatchRatio =
    template.normalizedDistances.isNotEmpty
        ? distMatches / template.normalizedDistances.length
        : 0.0;

    final matched = posMatchRatio >= posMatchRatioThreshold &&
        distMatchRatio >= distanceMatchRatioThreshold;

    return {
      'matched': matched,
      'suggestion': matched
          ? 'Pose Matched! Ready to capture.'
          : 'Adjust your pose to match the guide',
      'avgDistance': avgDistance,
      'matchRatio': posMatchRatio,
      'distanceMatchRatio': distMatchRatio,
    };
  }

  /// Normalize by torso size (scale invariant)
  List<PoseLandmark> _normalizeLandmarks(List<PoseLandmark> lms) {
    PoseLandmark getOr(PoseLandmarkType t, PoseLandmark fb) =>
        lms.firstWhere((e) => e.type == t, orElse: () => fb);

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

  /// Dialog after capturing a matched pose
  Future<void> _showCapturedPoseDialog(String imagePath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pose Captured'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath), height: 200),
            const SizedBox(height: 16),
            Text(
              'Position AvgDist: ${_avgPosDistance.toStringAsFixed(3)}\n'
                  'Position Match: ${(_posMatchRatio * 100).toStringAsFixed(1)}%\n'
                  'Distance Match: ${(_distMatchRatio * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _poseMatched = false;
                _suggestion = '';
                _currentPose = null;
                _hasCaptured = false;
                _avgPosDistance = 0.0;
                _posMatchRatio = 0.0;
                _distMatchRatio = 0.0;
              });
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pop(); // back to SavedTemplatesPage
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Scan Pose: ${widget.template.name}')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          /// Draw saved template landmarks as overlay (reference pose)
          CustomPaint(
            painter: WithoutBackgroundPose(
              pose: widget.template.landmarksToPose(),
              imageSize: widget.template.imageSize,
            ),
          ),

          /// Live suggestion / match %
          if (_suggestion.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_suggestion\n'
                      'AvgDist: ${_avgPosDistance.toStringAsFixed(3)} | '
                      'Pos: ${(_posMatchRatio * 100).toStringAsFixed(1)}% | '
                      'Dist: ${(_distMatchRatio * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
