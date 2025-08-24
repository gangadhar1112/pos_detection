import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pos_detection/model/pose_template.dart';
import 'package:pos_detection/with_out_image_pose.dart'; // Your custom painter for template pose

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
  String _suggestion = '';
  Pose? _currentPose;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _startCamera();
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
    if (mounted) {
      setState(() {
        _controller = controller;
      });
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _controller == null || _poseDetector == null) return;

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(
        image,
        _controller!.description.sensorOrientation,
      );

      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        final detectedPose = poses.first;

        final matchResult = _compareWithTemplate(detectedPose, widget.template);
        setState(() {
          _currentPose = detectedPose;
          _poseMatched = matchResult['matched'];
          _suggestion = matchResult['suggestion'];
        });
      } else {
        setState(() {
          _currentPose = null;
          _poseMatched = false;
          _suggestion = 'No pose detected';
        });
      }
    } catch (e) {
      print('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image, int rotation) {
    final bytes = WriteBuffer();
    for (final plane in image.planes) {
      bytes.putUint8List(plane.bytes);
    }
    final allBytes = bytes.done().buffer.asUint8List();

    final size = Size(image.width.toDouble(), image.height.toDouble());

    final inputRotation =
        InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg;

    final metadata = InputImageMetadata(
      size: size,
      rotation: inputRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: allBytes, metadata: metadata);
  }

  // Bounding box around key landmarks (shoulders + hips)
  Rect _boundingBoxAroundKeyPoints(List<PoseLandmark> landmarks) {
    final keyTypes = {
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    };

    final keyPoints = landmarks.where((lm) => keyTypes.contains(lm.type)).toList();

    if (keyPoints.isEmpty) {
      return Rect.fromLTWH(0, 0, 1, 1);
    }

    double minX = keyPoints.map((lm) => lm.x).reduce(min);
    double maxX = keyPoints.map((lm) => lm.x).reduce(max);
    double minY = keyPoints.map((lm) => lm.y).reduce(min);
    double maxY = keyPoints.map((lm) => lm.y).reduce(max);

    // Add small padding
    final paddingX = (maxX - minX) * 0.1;
    final paddingY = (maxY - minY) * 0.1;

    return Rect.fromLTRB(
      minX - paddingX,
      minY - paddingY,
      maxX + paddingX,
      maxY + paddingY,
    );
  }

  // Normalize landmarks by bounding box (translate and scale to [0..1])
  List<PoseLandmark> _normalizeLandmarks(List<PoseLandmark> landmarks) {
    final box = _boundingBoxAroundKeyPoints(landmarks);

    final width = box.width != 0 ? box.width : 1.0;
    final height = box.height != 0 ? box.height : 1.0;

    return landmarks.map((lm) {
      return PoseLandmark(
        type: lm.type,
        x: (lm.x - box.left) / width,
        y: (lm.y - box.top) / height,
        z: lm.z,
        likelihood: lm.likelihood,
      );
    }).toList();
  }

  Map<String, dynamic> _compareWithTemplate(Pose detected, PoseTemplate template) {
    const double distanceThreshold = 0.15; // Adjust threshold if needed
    const double matchRatioThreshold = 0.8; // 80% landmarks must match

    final templateLandmarks = template.landmarks;
    final detectedLandmarks = detected.landmarks.values.toList();

    // Normalize both
    final normalizedTemplate = _normalizeLandmarks(templateLandmarks);
    final normalizedDetected = _normalizeLandmarks(detectedLandmarks);

    // Map detected normalized landmarks by type for quick lookup
    final detectedMap = {
      for (var lm in normalizedDetected) lm.type: lm,
    };

    int matchedCount = 0;
    int totalCount = 0;

    for (final tmplLm in normalizedTemplate) {
      final detectedLm = detectedMap[tmplLm.type];

      if (detectedLm != null) {
        final dx = tmplLm.x - detectedLm.x;
        final dy = tmplLm.y - detectedLm.y;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist <= distanceThreshold) {
          matchedCount++;
        }
        totalCount++;
      }
    }

    final matchRatio = totalCount > 0 ? matchedCount / totalCount : 0;

    print('Match ratio: $matchRatio ($matchedCount/$totalCount)');

    if (matchRatio >= matchRatioThreshold) {
      return {'matched': true, 'suggestion': 'Pose Matched! Ready to capture.'};
    } else {
      return {'matched': false, 'suggestion': 'Adjust your pose to match the guide'};
    }
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cameraSize = _controller!.value.previewSize!;
    final screenSize = MediaQuery.of(context).size;

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final previewSize = isPortrait
        ? Size(cameraSize.height, cameraSize.width)
        : cameraSize;

    return Scaffold(
      appBar: AppBar(title: Text('Scan Pose: ${widget.template.name}')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // ONLY draw the static/template pose (remove live pose painter)
          CustomPaint(
            painter: WithoutBackgroundPose(
              pose: widget.template.landmarksToPose(),
              imageSize: widget.template.imageSize,
            ),
          ),

          // Remove or comment out any CustomPaint that uses live _currentPose

          // Overlay match status or suggestions
          if (_suggestion.isNotEmpty)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _suggestion,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),

          // Show button only if matched
          if (_poseMatched)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pose captured!')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Capture Pose'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Painter for live detected pose landmarks
class LivePosePainter extends CustomPainter {
  final Pose pose;
  final Size imageSize;
  final Color color;

  LivePosePainter({
    required this.pose,
    required this.imageSize,
    this.color = Colors.red,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    // Draw points
    for (final lm in pose.landmarks.values) {
      final offset = Offset(lm.x * scaleX, lm.y * scaleY);
      canvas.drawCircle(offset, 6.0, paint);
    }

    // Draw lines between connected landmarks (simple skeleton)
    void drawLine(PoseLandmarkType a, PoseLandmarkType b) {
      final lmA = pose.landmarks[a];
      final lmB = pose.landmarks[b];
      if (lmA != null && lmB != null) {
        final p1 = Offset(lmA.x * scaleX, lmA.y * scaleY);
        final p2 = Offset(lmB.x * scaleX, lmB.y * scaleY);
        canvas.drawLine(p1, p2, paint);
      }
    }

    // Example skeleton connections - add as needed
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant LivePosePainter oldDelegate) {
    return oldDelegate.pose != pose;
  }
}
