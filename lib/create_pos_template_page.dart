import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:pos_detection/pos.dart';
import 'package:pos_detection/with_out_image_pose.dart';
import 'model/pose_template.dart';

class CreatePoseTemplatePage extends StatefulWidget {
  final Function(PoseTemplate) onTemplateCreated;

  const CreatePoseTemplatePage({required this.onTemplateCreated, Key? key})
    : super(key: key);

  @override
  State<CreatePoseTemplatePage> createState() => _CreatePoseTemplatePageState();
}

class _CreatePoseTemplatePageState extends State<CreatePoseTemplatePage> {
  CameraController? _controller;
  late PoseDetector _poseDetector;
  bool _isDetecting = false;

  Pose? _currentPose;
  String? _capturedPath;
  String _poseName = '';

  Size? _previewSize;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();

    // Pick front or back camera as you want
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _isFrontCamera = camera.lensDirection == CameraLensDirection.back;

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();

    _previewSize = _controller!.value.previewSize;

    await _controller!.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      if (image.format.group == ImageFormatGroup.yuv420) {
        final inputImage = _convertCameraImage(
          image,
          _controller!.description.sensorOrientation,
        );
        final poses = await _poseDetector.processImage(inputImage);
        if (poses.isNotEmpty) {
          setState(() {
            _currentPose = poses.first;
          });
        }
      }
    } catch (e) {
      print('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image, int sensorOrientation) {
    final bytes = Uint8List(image.planes.first.bytes.length);
    int offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final inputImageRotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: inputImageRotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  Future<void> _capturePoseTemplate() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final XFile picture = await _controller!.takePicture();

    setState(() {
      _capturedPath = picture.path;
    });

    final inputImage = InputImage.fromFilePath(picture.path);
    final poses = await _poseDetector.processImage(inputImage);

    if (poses.isNotEmpty) {
      final pose = poses.first;

      final bytes = await File(picture.path).readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      final imageSize = decodedImage == null
          ? Size.zero
          : Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());

      final template = PoseTemplate(
        name: _poseName,
        imagePath: picture.path,
        landmarks: pose.landmarks.values.toList(),
        imageSize: imageSize,
      );

      widget.onTemplateCreated(template);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pose detected in captured image')),
      );
    }
  }

  @override
  void dispose() {
    _poseDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Pose Template')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final targetSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              if (_currentPose != null && _previewSize != null)
                CustomPaint(
                  painter: WithoutBackgroundPose(
                    pose: _currentPose!,
                    imageSize: _previewSize!,
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min, // so it hugs content height
            children: [
              if (_capturedPath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Image.file(File(_capturedPath!), height: 120),
                ),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Pose Name',
                ),
                onChanged: (value) {
                  setState(() {
                    _poseName = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _poseName.isNotEmpty ? _capturePoseTemplate : null,
                child: const Text('Capture & Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
