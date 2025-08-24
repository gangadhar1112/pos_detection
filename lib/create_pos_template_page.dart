import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(options: PoseDetectorOptions());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

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
          setState(() => _currentPose = poses.first);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Pose detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image, int sensorOrientation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final meta = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: meta);
  }

  Future<void> _capturePoseTemplate() async {
    if (_controller == null || !_controller!.value.isInitialized || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final XFile picture = await _controller!.takePicture();
      setState(() => _capturedPath = picture.path);

      final inputImage = InputImage.fromFilePath(picture.path);
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No pose detected in captured image')));
        return;
      }

      final pose = poses.first;

      final bytes = await File(picture.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      final imageSize = decoded == null
          ? const Size(0, 0)
          : Size(decoded.width.toDouble(), decoded.height.toDouble());

      final template = PoseTemplate.fromDetectedPose(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _poseName,
        imagePath: picture.path,
        imageSize: imageSize,
        pose: pose,
      );

      widget.onTemplateCreated(template);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (kDebugMode) print('Error saving pose: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          // if (_currentPose != null && _previewSize != null)
          //   CustomPaint(
          //     painter: PosePainter(
          //       pose: _currentPose!,
          //       imageSize: _previewSize!, // camera frame size
          //       widgetSize: Size(
          //         MediaQuery.of(context).size.width,
          //         MediaQuery.of(context).size.height -
          //             kToolbarHeight -
          //             MediaQuery.of(context).padding.top,
          //       ),
          //       isFrontCamera:false,
          //     ),
          //   ),
          if (_isSaving)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                onChanged: (v) => setState(() => _poseName = v),
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
