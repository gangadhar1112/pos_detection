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
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pose detected in captured image')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  BackButton(color: Colors.white),
                  Text(
                    "Create Pose Template",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 48), // Spacer for symmetry
                ],
              ),
            ),
          ),

          // Bottom Controls
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Thumbnail Preview
                    if (_capturedPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_capturedPath!),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Pose Name Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: TextField(
                        style: TextStyle(color: Colors.black),

                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(12),
                          border: InputBorder.none,
                          hintText: 'Enter Pose Name',
                          hintStyle: TextStyle(color: Colors.black),
                          prefixIcon: Icon(Icons.edit,color: Colors.black),
                        ),
                        onChanged: (v) => setState(() => _poseName = v),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Capture Button
                    GestureDetector(
                      onTap: _poseName.isNotEmpty ? _capturePoseTemplate : null,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                            color: _poseName.isNotEmpty
                                ? Colors.redAccent
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Saving Overlay
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
