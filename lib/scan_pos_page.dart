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

class _ScanPosePageState extends State<ScanPosePage>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _startCamera();

    _glowController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

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

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _controller == null || _poseDetector == null || _hasCaptured) return;
    _isDetecting = true;

    try {
      final inputImage =
      _convertCameraImage(image, _controller!.description.sensorOrientation);
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

  Map<String, dynamic> _compareWithTemplate(Pose detected, PoseTemplate template) {
    const double perLandmarkThreshold = 0.12;
    const double posMatchRatioThreshold = 0.75;

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
    final avgDistance =
    comparedCount > 0 ? totalDistance / comparedCount : double.infinity;

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
      'suggestion':
      matched ? '✅ Perfect Pose!' : '⚠️ Adjust your position...',
      'avgDistance': avgDistance,
      'matchRatio': posMatchRatio,
      'distanceMatchRatio': distMatchRatio,
    };
  }

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

  Future<void> _showCapturedPoseDialog(String imagePath) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Pose Captured!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath), height: 200, fit: BoxFit.cover),
            const SizedBox(height: 16),
            _buildStatCard("Position", "${(_posMatchRatio * 100).toStringAsFixed(1)}%"),
            _buildStatCard("Distance", "${(_distMatchRatio * 100).toStringAsFixed(1)}%"),
            _buildStatCard("Avg Dist", _avgPosDistance.toStringAsFixed(3)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.blue,
            ),
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
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.blue.shade600),
            const SizedBox(width: 10),
            Text("$title: ",
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector?.close();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('📸 Match Pose: ${widget.template.name}'),
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          CustomPaint(
            painter: WithoutBackgroundPose(
              pose: widget.template.landmarksToPose(),
              imageSize: widget.template.imageSize,
            ),
          ),

          if (_suggestion.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: ScaleTransition(
                scale: Tween(begin: 0.95, end: 1.05)
                    .animate(CurvedAnimation(parent: _glowController, curve: Curves.easeInOut)),
                child: Container(
                  margin: const EdgeInsets.only(top: 30),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _poseMatched
                          ? [Colors.greenAccent.shade400, Colors.green.shade700]
                          : [Colors.redAccent.shade200, Colors.red.shade600],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _poseMatched ? Colors.greenAccent : Colors.redAccent,
                        blurRadius: 12,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Text(
                    '$_suggestion\n📊 Pos: ${(_posMatchRatio * 100).toStringAsFixed(1)}% | '
                        'Dist: ${(_distMatchRatio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
