import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;
import 'package:pos_detection/with_out_image_pose.dart';

import 'dashboard.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({required this.camera, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Detection Camera',
      theme: ThemeData.dark(),
      //home: PoseCameraPage(camera: camera),
      home:const DashboardPage(),
    );
  }
}

// class PoseCameraPage extends StatefulWidget {
//   final CameraDescription camera;
//
//   const PoseCameraPage({required this.camera, Key? key}) : super(key: key);
//
//   @override
//   _PoseCameraPageState createState() => _PoseCameraPageState();
// }
//
// class _PoseCameraPageState extends State<PoseCameraPage> {
//   late CameraController _controller;
//   late PoseDetector _poseDetector;
//   bool _isDetecting = false;
//   Pose? _currentPose;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _poseDetector = PoseDetector(
//       options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
//     );
//
//     _controller = CameraController(
//       widget.camera,
//       ResolutionPreset.ultraHigh,
//       enableAudio: false,
//     );
//
//     _controller.initialize().then((_) {
//       if (!mounted) return;
//       _controller.startImageStream(_processCameraImage);
//       setState(() {});
//     });
//   }
//
//   void _processCameraImage(CameraImage image) async {
//     if (_isDetecting) return;
//     _isDetecting = true;
//
//     try {
//       if (image.format.group == ImageFormatGroup.yuv420) {
//         final inputImage = _convertCameraImage(
//           image,
//           widget.camera.sensorOrientation,
//         );
//         final poses = await _poseDetector.processImage(inputImage);
//         if (poses.isNotEmpty) {
//           setState(() {
//             _currentPose = poses.first;
//           });
//         } else {
//           setState(() {
//             _currentPose = null;
//           });
//         }
//       } else {
//         print('Skipping unsupported image format: ${image.format.group}');
//       }
//     } catch (e) {
//       print('Pose detection error: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }
//
//   InputImage _convertCameraImage(CameraImage image, int sensorOrientation) {
//     final bytes = Uint8List(image.planes.first.bytes.length);
//     int offset = 0;
//     for (final plane in image.planes) {
//       bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
//       offset += plane.bytes.length;
//     }
//
//     final Size imageSize = Size(
//       image.width.toDouble(),
//       image.height.toDouble(),
//     );
//
//     final inputImageRotation =
//         InputImageRotationValue.fromRawValue(sensorOrientation) ??
//         InputImageRotation.rotation0deg;
//
//     // Use nv21 format on Android
//     final inputImageMetadata = InputImageMetadata(
//       size: imageSize,
//       rotation: inputImageRotation,
//       format: InputImageFormat.nv21,
//       bytesPerRow: image.planes[0].bytesPerRow,
//     );
//
//     return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
//   }
//
//   Future<Size> getImageSize(String path) async {
//     final bytes = await File(path).readAsBytes();
//     final decodedImage = img.decodeImage(bytes);
//     if (decodedImage == null) {
//       throw Exception("Failed to decode image");
//     }
//     return Size(decodedImage.width.toDouble(), decodedImage.height.toDouble());
//   }
//
//   Future<void> _captureImageAndDetectPose() async {
//     if (!_controller.value.isInitialized || _isDetecting) return;
//     _isDetecting = true;
//
//     try {
//       final XFile file = await _controller.takePicture();
//
//       final inputImage = InputImage.fromFilePath(file.path);
//       final poses = await _poseDetector.processImage(inputImage);
//
//       if (poses.isNotEmpty) {
//         final detectedPose = poses.first;
//
//         // Get real image size here:
//         final imageSize = await getImageSize(file.path);
//
//         if (!mounted) return;
//         Navigator.of(context).push(
//           MaterialPageRoute(
//             builder: (_) => PoseResultPage(
//               imagePath: file.path,
//               pose: detectedPose,
//               imageSize: imageSize,
//             ),
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('No pose detected in the captured image'),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Capture error: $e');
//     } finally {
//       _isDetecting = false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _poseDetector.close();
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (!_controller.value.isInitialized) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Pose Detection Camera')),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           CameraPreview(_controller),
//           if (_currentPose != null)
//             CustomPaint(
//               size: Size.infinite,
//               painter: WithoutBackgroundPose(
//                 pose:_currentPose!,
//                 imageSize: _controller.value.previewSize!,
//               ),
//             ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _captureImageAndDetectPose,
//         child: const Icon(Icons.camera_alt),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
//     );
//   }
// }
//
// class PoseResultPage extends StatelessWidget {
//   final String imagePath;
//   final Pose pose;
//   final Size imageSize; // Pass image size here
//
//   const PoseResultPage({
//     required this.imagePath,
//     required this.pose,
//     required this.imageSize,
//     super.key,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Pose Result')),
//       body: Stack(
//         fit: StackFit.expand,
//         children: [
//           Image.file(File(imagePath), fit: BoxFit.cover),
//           CustomPaint(
//             painter: WithoutBackgroundPose(pose: pose, imageSize: imageSize),
//           ),
//         ],
//       ),
//     );
//   }
// }
