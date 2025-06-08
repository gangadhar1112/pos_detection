import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

class OutlinePos extends StatefulWidget {
  final Pose pose;
  final String imagePath;
  final Size imageSize;

  const OutlinePos({
    super.key,
    required this.pose,
    required this.imagePath,
    required this.imageSize,
  });

  @override
  State<OutlinePos> createState() => _OutlinePosState();
}

class _OutlinePosState extends State<OutlinePos> {
  Rect? boundingBox;
  ui.Image? croppedUiImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cropImageFromPose());
  }

  Rect _calculatePoseBoundingBox(Pose pose, Size imageSize, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;

    double? minX, minY, maxX, maxY;
    for (final landmark in pose.landmarks.values) {
      final x = landmark.x * scaleX;
      final y = landmark.y * scaleY;
      if (minX == null || x < minX) minX = x;
      if (minY == null || y < minY) minY = y;
      if (maxX == null || x > maxX) maxX = x;
      if (maxY == null || y > maxY) maxY = y;
    }

    return Rect.fromLTRB(
      (minX ?? 0) - 20,
      (minY ?? 0) - 20,
      (maxX ?? canvasSize.width) + 20,
      (maxY ?? canvasSize.height) + 20,
    );
  }

  Future<void> _cropImageFromPose() async {
    final originalBytes = await File(widget.imagePath).readAsBytes();
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) return;

    final box = _calculatePoseBoundingBox(widget.pose, widget.imageSize, widget.imageSize);

    final cropped = img.copyCrop(
      decodedImage,
      x: box.left.clamp(0, decodedImage.width.toDouble()).toInt(),
      y: box.top.clamp(0, decodedImage.height.toDouble()).toInt(),
      width: box.width.clamp(1, decodedImage.width.toDouble()).toInt(),
      height: box.height.clamp(1, decodedImage.height.toDouble()).toInt(),
    );

    final uiImage = await _convertToUiImage(cropped);
    setState(() {
      boundingBox = box;
      croppedUiImage = uiImage;
    });
  }

  Future<ui.Image> _convertToUiImage(img.Image image) async {
    final pngBytes = img.encodePng(image);
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(pngBytes));
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Cropped Pose View")),
      body: Center(
        child: croppedUiImage != null
            ? RawImage(image: croppedUiImage)
            : const CircularProgressIndicator(),
      ),
    );
  }
}
