import 'dart:io';

import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class CameraView extends StatefulWidget {
  const CameraView(
      {Key? key,
        required this.customPaint,
        required this.onImage,
        this.onCameraFeedReady,
        this.onDetectorViewModeChanged,
        this.onCameraLensDirectionChanged,
        this.initialCameraLensDirection = CameraLensDirection.back,})
      : super(key: key);

  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final VoidCallback? onCameraFeedReady;
  final VoidCallback? onDetectorViewModeChanged;
  final Function(CameraLensDirection direction)? onCameraLensDirectionChanged;
  final CameraLensDirection initialCameraLensDirection;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  static List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;
  bool _changingCameraLens = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initialize() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == widget.initialCameraLensDirection) {
        _cameraIndex = i;
        break;
      }
    }
    if (_cameraIndex != -1) {
      _startLiveFeed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    print(state);
    if (state == AppLifecycleState.paused) {
      // O aplicativo foi minimizado, desligue a câmera
      _stopLiveFeed();
    } else if (state == AppLifecycleState.resumed) {
      // O aplicativo foi restaurado, ligue a câmera novamente
      _startLiveFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
          _liveFeedBody(),
        ],
      ),
    );

  }

  Widget _liveFeedBody() {
    if (_cameras.isEmpty || _controller == null || !_controller!.value.isInitialized) {
      return Container();
    }
    double screenHeight = MediaQuery.of(context).size.height;
    return Center(
      child: Container(
        height: screenHeight,
        child: Stack(
          children: <Widget>[
            Center(
              child: ClipRRect(
                child: _changingCameraLens
                    ? const Center(
                  child: Text('Changing camera lens'),
                )
                    : CameraPreview(
                  _controller!,
                  child: widget.customPaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future _startLiveFeed() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      final camera = _cameras[_cameraIndex];
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await _controller?.initialize();
    }
    if (!mounted) {
      return;
    }
    _controller?.startImageStream(_processCameraImage).then((value) {
      if (widget.onCameraFeedReady != null) {
        widget.onCameraFeedReady!();
      }
    });
    setState(() {});
  }

  Future _stopLiveFeed() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller?.stopImageStream();
      await _controller?.dispose();
      _controller = null;
    }
  }

  Future<void> stopCameraFeed() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller?.stopImageStream();
    }
  }

  void _processCameraImage(CameraImage image) {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;
    widget.onImage(inputImage);
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
      _orientations[_controller!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
