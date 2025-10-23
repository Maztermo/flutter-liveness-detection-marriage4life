// ignore_for_file: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_liveness_detection_randomized_plugin/index.dart';
import 'package:flutter_liveness_detection_randomized_plugin/src/core/constants/liveness_detection_step_constant.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

List<CameraDescription> availableCams = [];

class LivenessDetectionView extends StatefulWidget {
  final LivenessDetectionConfig config;
  final bool isEnableSnackBar;
  final bool shuffleListWithSmileLast;
  final bool showCurrentStep;
  final bool isDarkMode;

  const LivenessDetectionView({
    super.key,
    required this.config,
    required this.isEnableSnackBar,
    this.isDarkMode = true,
    this.showCurrentStep = false,
    this.shuffleListWithSmileLast = true,
  });

  @override
  State<LivenessDetectionView> createState() => _LivenessDetectionScreenState();
}

class _LivenessDetectionScreenState extends State<LivenessDetectionView> {
  // Camera related variables
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  int _frameCounter = 0; // Keep for debug logging only

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _isProcessingStep = false;
  bool _faceDetectedState = false;
  static late List<LivenessDetectionStepItem> _cachedShuffledSteps;
  static bool _isShuffled = false;

  // Brightness Screen
  Future<void> setApplicationBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(brightness);
    } catch (e) {
      throw 'Failed to set application brightness';
    }
  }

  Future<void> resetApplicationBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (e) {
      throw 'Failed to reset application brightness';
    }
  }

  // Steps related variables
  late final List<LivenessDetectionStepItem> steps;
  final GlobalKey<LivenessDetectionStepOverlayWidgetState> _stepsKey = GlobalKey<LivenessDetectionStepOverlayWidgetState>();

  static void shuffleListLivenessChallenge({
    required List<LivenessDetectionStepItem> list,
    required bool isSmileLast,
  }) {
    if (isSmileLast) {
      int? blinkIndex = list.indexWhere((item) => item.step == LivenessDetectionStep.blink);
      int? smileIndex = list.indexWhere((item) => item.step == LivenessDetectionStep.smile);

      if (blinkIndex != -1 && smileIndex != -1) {
        LivenessDetectionStepItem blinkItem = list.removeAt(blinkIndex);
        LivenessDetectionStepItem smileItem = list.removeAt(smileIndex > blinkIndex ? smileIndex - 1 : smileIndex);
        list.shuffle(Random());
        list.insert(list.length - 1, blinkItem);
        list.add(smileItem);
      } else {
        list.shuffle(Random());
      }
    } else {
      list.shuffle(Random());
    }
  }

  Future<XFile?> _compressImage(XFile originalFile) async {
    final int quality = widget.config.imageQuality;

    if (quality >= 100) {
      return originalFile;
    }

    try {
      final bytes = await originalFile.readAsBytes();

      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        return originalFile;
      }

      final tempDir = await getTemporaryDirectory();
      final String targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedBytes = img.encodeJpg(originalImage, quality: quality);

      final File compressedFile = await File(targetPath).writeAsBytes(compressedBytes);

      return XFile(compressedFile.path);
    } catch (e) {
      debugPrint("Error compressing image: $e");
      return originalFile;
    }
  }

  List<T> manualRandomItemLiveness<T>(List<T> list) {
    final random = Random();
    List<T> shuffledList = List.from(list);
    for (int i = shuffledList.length - 1; i > 0; i--) {
      int j = random.nextInt(i + 1);

      T temp = shuffledList[i];
      shuffledList[i] = shuffledList[j];
      shuffledList[j] = temp;
    }
    return shuffledList;
  }

  List<LivenessDetectionStepItem> customizedLivenessLabel(LivenessDetectionLabelModel label) {
    if (!_isShuffled) {
      List<LivenessDetectionStepItem> customizedSteps = [];

      if (label.blink != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.blink,
          title: label.blink ?? "Blink 2-3 Times",
        ));
      }

      if (label.lookRight != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookRight,
          title: label.lookRight ?? "Look Right",
        ));
      }

      if (label.lookLeft != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookLeft,
          title: label.lookLeft ?? "Look Left",
        ));
      }

      if (label.lookUp != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookUp,
          title: label.lookUp ?? "Look Up",
        ));
      }

      if (label.lookDown != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.lookDown,
          title: label.lookDown ?? "Look Down",
        ));
      }

      if (label.smile != "" && widget.config.useCustomizedLabel) {
        customizedSteps.add(LivenessDetectionStepItem(
          step: LivenessDetectionStep.smile,
          title: label.smile ?? "Smile",
        ));
      }
      _cachedShuffledSteps = manualRandomItemLiveness(customizedSteps);
      _isShuffled = true;
    }

    return _cachedShuffledSteps;
  }

  @override
  void initState() {
    _preInitCallBack();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _postFrameCallBack());
  }

  @override
  void dispose() {
    _timerToDetectFace?.cancel();
    _timerToDetectFace = null;
    _cameraController?.dispose();
    shuffleListLivenessChallenge(
        list: widget.config.useCustomizedLabel && widget.config.customizedLabel != null
            ? customizedLivenessLabel(widget.config.customizedLabel!)
            : stepLiveness,
        isSmileLast: widget.config.useCustomizedLabel ? false : widget.shuffleListWithSmileLast);
    if (widget.config.isEnableMaxBrightness) {
      resetApplicationBrightness();
    }
    super.dispose();
  }

  void _preInitCallBack() {
    _isInfoStepCompleted = !widget.config.startWithInfoScreen;
    shuffleListLivenessChallenge(
        list: widget.config.useCustomizedLabel && widget.config.customizedLabel != null
            ? customizedLivenessLabel(widget.config.customizedLabel!)
            : stepLiveness,
        isSmileLast: widget.config.useCustomizedLabel ? false : widget.shuffleListWithSmileLast);
    if (widget.config.isEnableMaxBrightness) {
      setApplicationBrightness(1.0);
    }
  }

  void _postFrameCallBack() async {
    availableCams = await availableCameras();
    if (availableCams.any((element) => element.lensDirection == CameraLensDirection.front && element.sensorOrientation == 90)) {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere((element) => element.lensDirection == CameraLensDirection.front && element.sensorOrientation == 90),
      );
    } else {
      _cameraIndex = availableCams.indexOf(
        availableCams.firstWhere((element) => element.lensDirection == CameraLensDirection.front),
      );
    }
    if (!widget.config.startWithInfoScreen) {
      _startLiveFeed();
    }

    shuffleListLivenessChallenge(
        list: widget.config.useCustomizedLabel && widget.config.customizedLabel != null
            ? customizedLivenessLabel(widget.config.customizedLabel!)
            : stepLiveness,
        isSmileLast: widget.shuffleListWithSmileLast);
  }

  void _startLiveFeed() async {
    final camera = availableCams[_cameraIndex];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high, // High resolution for better image quality
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Request YUV420 format (Android uses NV21 variant)
    );

    _cameraController?.initialize().then((_) {
      if (!mounted) return;
      _cameraController?.startImageStream(_processCameraImage);
      setState(() {});
    });
    _startFaceDetectionTimer();
  }

  void _startFaceDetectionTimer() {
    _timerToDetectFace =
        Timer(Duration(seconds: widget.config.durationLivenessVerify ?? 45), () => _onDetectionCompleted(imgToReturn: null));
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    _frameCounter++;

    // Debug logging every 30 frames
    if (_frameCounter % 30 == 0) {
      debugPrint('\n=== FRAME $_frameCounter DEBUG ===');
      debugPrint('Image: ${cameraImage.width}x${cameraImage.height}');
      debugPrint('Format group: ${cameraImage.format.group}');
      debugPrint('Format raw: ${cameraImage.format.raw}');
      debugPrint('Planes: ${cameraImage.planes.length}');
      for (var i = 0; i < cameraImage.planes.length; i++) {
        debugPrint(
            '  Plane[$i]: bytesPerPixel=${cameraImage.planes[i].bytesPerPixel}, bytesPerRow=${cameraImage.planes[i].bytesPerRow}, length=${cameraImage.planes[i].bytes.length}');
      }
    }

    // For NV21: Y plane + interleaved UV plane (NOT all planes!)
    final yPlaneBytes = cameraImage.planes[0].bytes;

    // Check if this is the semi-planar format (NV21/NV12)
    if (cameraImage.planes[0].bytesPerPixel == 1 && cameraImage.planes.length > 1 && cameraImage.planes[1].bytesPerPixel == 2) {
      // Plane 1 is already interleaved UV data - use it directly!
      final uvPlaneBytes = cameraImage.planes[1].bytes;

      // 🔍 DEBUG: Log actual sizes
      if (_frameCounter % 30 == 0) {
        debugPrint('\n=== BYTE SIZE DEBUG ===');
        debugPrint('yPlaneBytes.length: ${yPlaneBytes.length}');
        debugPrint('uvPlaneBytes.length: ${uvPlaneBytes.length}');
        debugPrint('Expected Y: ${cameraImage.width * cameraImage.height}');
        debugPrint('Expected UV: ${(cameraImage.width * cameraImage.height / 2).toInt()}');
      }

      final WriteBuffer allBytes = WriteBuffer();
      allBytes.putUint8List(yPlaneBytes); // Add entire Y plane
      allBytes.putUint8List(uvPlaneBytes); // Add entire UV plane (no loop needed!)
      final bytes = allBytes.done().buffer.asUint8List();

      // Verify byte array size
      final expectedSize = (cameraImage.width * cameraImage.height * 1.5).toInt();

      if (_frameCounter % 30 == 0) {
        debugPrint('Final bytes.length: ${bytes.length}');
        debugPrint('Expected total: $expectedSize');
        if (bytes.length != expectedSize) {
          debugPrint('⚠️ SIZE MISMATCH! Difference: ${bytes.length - expectedSize}');
        }
        debugPrint('======================\n');
      }

      if (bytes.length != expectedSize) {
        debugPrint('⚠️ SIZE MISMATCH! Expected: $expectedSize, Got: ${bytes.length}');
        return;
      }

      final Size imageSize = Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      );

      final camera = availableCams[_cameraIndex];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);

      if (_frameCounter % 30 == 0) {
        debugPrint('Sensor orientation: ${camera.sensorOrientation}');
        debugPrint('Image rotation: $imageRotation');
      }

      if (imageRotation == null) {
        debugPrint('⚠️ imageRotation is null!');
        return;
      }

      // Use NV21 format for Android
      final inputImageFormat = Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21;

      if (_frameCounter % 30 == 0) {
        debugPrint('Input format: $inputImageFormat');
      }

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        metadata: inputImageData,
        bytes: bytes,
      );

      if (_frameCounter % 30 == 0) {
        debugPrint('Calling _processImage...\n');
      }

      _processImage(inputImage);
    } else {
      debugPrint('⚠️ Unexpected camera format!');
      debugPrint('  planes.length: ${cameraImage.planes.length}');
      debugPrint('  planes[0].bytesPerPixel: ${cameraImage.planes[0].bytesPerPixel}');
      if (cameraImage.planes.length > 1) {
        debugPrint('  planes[1].bytesPerPixel: ${cameraImage.planes[1].bytesPerPixel}');
      }
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_frameCounter % 30 == 0) {
      debugPrint('_processImage called. _isBusy: $_isBusy');
    }

    if (_isBusy) {
      if (_frameCounter % 30 == 0) {
        debugPrint('⚠️ Skipping frame - already busy');
      }
      return;
    }
    _isBusy = true;

    final faces = await MachineLearningKitHelper.instance.processInputImage(inputImage);

    if (_frameCounter % 30 == 0) {
      debugPrint('Faces from ML Kit: ${faces.length}');
    }

    if (inputImage.metadata?.size != null && inputImage.metadata?.rotation != null) {
      if (faces.isEmpty) {
        _resetSteps();
        if (mounted) setState(() => _faceDetectedState = false);
      } else {
        if (mounted) setState(() => _faceDetectedState = true);
        final currentIndex = _stepsKey.currentState?.currentIndex ?? 0;
        if (widget.config.useCustomizedLabel) {
          if (currentIndex < customizedLivenessLabel(widget.config.customizedLabel!).length) {
            _detectFace(
              face: faces.first,
              step: customizedLivenessLabel(widget.config.customizedLabel!)[currentIndex].step,
            );
          }
        } else {
          if (currentIndex < stepLiveness.length) {
            _detectFace(
              face: faces.first,
              step: stepLiveness[currentIndex].step,
            );
          }
        }
      }
    } else {
      _resetSteps();
    }

    _isBusy = false;
    if (mounted) setState(() {});
  }

  void _detectFace({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    if (_isProcessingStep) return;

    debugPrint('Current Step: $step');

    switch (step) {
      case LivenessDetectionStep.blink:
        await _handlingBlinkStep(face: face, step: step);
        break;

      case LivenessDetectionStep.lookRight:
        await _handlingTurnRight(face: face, step: step);
        break;

      case LivenessDetectionStep.lookLeft:
        await _handlingTurnLeft(face: face, step: step);
        break;

      case LivenessDetectionStep.lookUp:
        await _handlingLookUp(face: face, step: step);
        break;

      case LivenessDetectionStep.lookDown:
        await _handlingLookDown(face: face, step: step);
        break;

      case LivenessDetectionStep.smile:
        await _handlingSmile(face: face, step: step);
        break;
    }
  }

  Future<void> _completeStep({required LivenessDetectionStep step}) async {
    if (mounted) setState(() {});
    await HapticFeedback.mediumImpact();
    await _stepsKey.currentState?.nextPage();
    _stopProcessing();
  }

  void _takePicture() async {
    try {
      if (_cameraController == null || _isTakingPicture) return;

      if (mounted) setState(() => _isTakingPicture = true);
      await _cameraController?.stopImageStream();

      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) {
        _startLiveFeed();
        if (mounted) setState(() => _isTakingPicture = false);
        return;
      }

      final XFile? finalImage = await _compressImage(clickedImage);

      debugPrint('Final image path: ${finalImage?.path}');
      _onDetectionCompleted(imgToReturn: finalImage);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) setState(() => _isTakingPicture = false);
      _startLiveFeed();
    }
  }

  void _onDetectionCompleted({XFile? imgToReturn}) async {
    final String? imgPath = imgToReturn?.path;
    final File imageFile = File(imgPath ?? "");
    final int fileSizeInBytes = await imageFile.length();
    final double sizeInKb = fileSizeInBytes / 1024;
    debugPrint('Image result size : ${sizeInKb.toStringAsFixed(2)} KB');
    if (widget.isEnableSnackBar) {
      final snackBar = SnackBar(
        content: Text(imgToReturn == null
            ? 'Verification of liveness detection failed, please try again. (Exceeds time limit ${widget.config.durationLivenessVerify ?? 45} second.)'
            : 'Verification of liveness detection success!'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    if (!mounted) return;
    Navigator.of(context).pop(imgPath);
  }

  void _resetSteps() {
    if (widget.config.useCustomizedLabel) {
      for (var step in customizedLivenessLabel(widget.config.customizedLabel!)) {
        final index = customizedLivenessLabel(widget.config.customizedLabel!).indexWhere((p1) => p1.step == step.step);
        customizedLivenessLabel(widget.config.customizedLabel!)[index] =
            customizedLivenessLabel(widget.config.customizedLabel!)[index].copyWith();
      }
      if (_stepsKey.currentState?.currentIndex != 0) {
        _stepsKey.currentState?.reset();
      }
      if (mounted) setState(() {});
    } else {
      for (var step in stepLiveness) {
        final index = stepLiveness.indexWhere((p1) => p1.step == step.step);
        stepLiveness[index] = stepLiveness[index].copyWith();
      }
      if (_stepsKey.currentState?.currentIndex != 0) {
        _stepsKey.currentState?.reset();
      }
      if (mounted) setState(() {});
    }
  }

  void _startProcessing() {
    if (!mounted) return;
    if (mounted) setState(() => _isProcessingStep = true);
  }

  void _stopProcessing() {
    if (!mounted) return;
    if (mounted) setState(() => _isProcessingStep = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _isInfoStepCompleted
            ? _buildDetectionBody()
            : LivenessDetectionTutorialScreen(
                duration: widget.config.durationLivenessVerify ?? 45,
                isDarkMode: widget.isDarkMode,
                onStartTap: () {
                  if (mounted) setState(() => _isInfoStepCompleted = true);
                  _startLiveFeed();
                },
              ),
      ],
    );
  }

  Widget _buildDetectionBody() {
    if (_cameraController == null || _cameraController?.value.isInitialized == false) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          color: widget.isDarkMode ? Colors.black : Colors.white,
        ),
        LivenessDetectionStepOverlayWidget(
          cameraController: _cameraController,
          duration: widget.config.durationLivenessVerify,
          showDurationUiText: widget.config.showDurationUiText,
          isDarkMode: widget.isDarkMode,
          isFaceDetected: _faceDetectedState,
          camera: CameraPreview(_cameraController!),
          key: _stepsKey,
          steps: widget.config.useCustomizedLabel ? customizedLivenessLabel(widget.config.customizedLabel!) : stepLiveness,
          showCurrentStep: widget.showCurrentStep,
          onCompleted: () => Future.delayed(
            const Duration(milliseconds: 500),
            () => _takePicture(),
          ),
        ),
      ],
    );
  }

  Future<void> _handlingBlinkStep({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    final blinkThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdBlink) as LivenessThresholdBlink?;

    if ((face.leftEyeOpenProbability ?? 1.0) < (blinkThreshold?.leftEyeProbability ?? 0.25) &&
        (face.rightEyeOpenProbability ?? 1.0) < (blinkThreshold?.rightEyeProbability ?? 0.25)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _handlingTurnRight({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    if (Platform.isAndroid) {
      final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
          .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
      if ((face.headEulerAngleY ?? 0) < (headTurnThreshold?.rotationAngle ?? -30)) {
        _startProcessing();
        await _completeStep(step: step);
      }
    } else if (Platform.isIOS) {
      final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
          .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
      if ((face.headEulerAngleY ?? 0) > (headTurnThreshold?.rotationAngle ?? 30)) {
        _startProcessing();
        await _completeStep(step: step);
      }
    }
  }

  Future<void> _handlingTurnLeft({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    if (Platform.isAndroid) {
      final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
          .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
      if ((face.headEulerAngleY ?? 0) > (headTurnThreshold?.rotationAngle ?? 30)) {
        _startProcessing();
        await _completeStep(step: step);
      }
    } else if (Platform.isIOS) {
      final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
          .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
      if ((face.headEulerAngleY ?? 0) < (headTurnThreshold?.rotationAngle ?? -30)) {
        _startProcessing();
        await _completeStep(step: step);
      }
    }
  }

  Future<void> _handlingLookUp({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleX ?? 0) > (headTurnThreshold?.rotationAngle ?? 20)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _handlingLookDown({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleX ?? 0) < (headTurnThreshold?.rotationAngle ?? -15)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _handlingSmile({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    final smileThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdSmile) as LivenessThresholdSmile?;

    if ((face.smilingProbability ?? 0) > (smileThreshold?.probability ?? 0.65)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }
}
