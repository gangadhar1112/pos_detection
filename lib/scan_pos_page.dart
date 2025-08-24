import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:pos_detection/model/pose_template.dart';
import 'package:pos_detection/with_out_image_pose.dart';

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

        final matchResult = _compareWithTemplate(detectedPose, widget.template);
        setState(() {
          _currentPose = detectedPose;
          _poseMatched = matchResult['matched'];
          _suggestion = matchResult['suggestion'];
        });

        if (matchResult['matched'] && !_hasCaptured) {
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
        });
      }
    } catch (e) {
      print('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image, int rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }

    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final inputRotation =
        InputImageRotationValue.fromRawValue(rotation) ?? InputImageRotation.rotation0deg;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: inputRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  Map<String, dynamic> _compareWithTemplate(Pose detected, PoseTemplate template) {
    const double distanceThreshold = 0.15;
    const double matchRatioThreshold = 0.8;

    final templateLandmarks = template.landmarks;
    final detectedLandmarks = detected.landmarks.values.toList();

    final normalizedTemplate = _normalizeLandmarks(templateLandmarks);
    final normalizedDetected = _normalizeLandmarks(detectedLandmarks);

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

    return {
      'matched': matchRatio >= matchRatioThreshold,
      'suggestion': matchRatio >= matchRatioThreshold
          ? 'Pose Matched! Ready to capture.'
          : 'Adjust your pose to match the guide',
    };
  }

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

    final paddingX = (maxX - minX) * 0.1;
    final paddingY = (maxY - minY) * 0.1;

    return Rect.fromLTRB(
      minX - paddingX,
      minY - paddingY,
      maxX + paddingX,
      maxY + paddingY,
    );
  }

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
            const Text('Your pose was successfully captured.'),
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
              });

              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Optional: Go back to dashboard
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

          // Template pose overlay
          CustomPaint(
            painter: WithoutBackgroundPose(
              pose: widget.template.landmarksToPose(),
              imageSize: widget.template.imageSize,
            ),
          ),

          // Match suggestion overlay
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

          // Optional capture button if needed
          if (_poseMatched)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pose captured!')),
                    );
                  },
                  icon: const Icon(Icons.check, color: Colors.black),
                  label: const Text('Capture Pose'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 18, color: Colors.black),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
