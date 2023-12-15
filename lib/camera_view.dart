import 'dart:io';

import 'package:camera/camera.dart';
import 'package:face_detection_ml_kit/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class CameraView extends StatefulWidget {
  final String title;
  final CustomPaint? customPaint;
  final String? text;
  final Function(InputImage inputImage) onImage;
  final CameraLensDirection initialDirection;

  const CameraView({
    Key? key,
    required this.title,
    required this.onImage,
    required this.initialDirection,
    this.customPaint,
    this.text,
  }) : super(key: key);

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  int _cameraIndex = 0;

  bool _chagingCameraLens = false;

  @override
  void initState() {
    super.initState();
    if (cameras.any(
          (element) =>
      element.lensDirection == widget.initialDirection &&
          element.sensorOrientation == 99,
    )) {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
              (element) =>
          element.lensDirection == widget.initialDirection &&
              element.sensorOrientation == 99,
        ),
      );
    } else {
      _cameraIndex = cameras.indexOf(
        cameras.firstWhere(
                (element) => element.lensDirection == widget.initialDirection),
      );
    }

    _startLive();
  }

  Future _startLive() async {
    final camera = cameras[_cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      _controller?.startImageStream(_processCameraImage);
      setState(() {});
    });
  }

  Future _processCameraImage(final CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final camera = cameras[_cameraIndex];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;
    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;
    final planeData = image.planes.map((final Plane plane) {
      return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width);
    }).toList();
    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );
    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      inputImageData: inputImageData,
    );
    widget.onImage(inputImage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _body(),
    );
  }

  Widget _body() {
    Widget body;
    body = _liveBody();
    return body;
  }

  Widget _liveBody() {
    if (_controller?.value.isInitialized == false) {
      return Container();
    }
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * _controller!.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: _chagingCameraLens
                  ? const Center(
                child: Text("Changing camera lens"),
              )
                  : CameraPreview(_controller!),
            ),
          ),
          if (widget.customPaint != null) widget.customPaint!,
        ],
      ),
    );
  }

  Future _stopLive() async {
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _controller = null;
  }
}