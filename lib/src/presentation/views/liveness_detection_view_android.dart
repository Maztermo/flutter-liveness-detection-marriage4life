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

class LivenessDetectionViewAndroid extends StatefulWidget {
  final LivenessDetectionConfig config;
  final bool isEnableSnackBar;
  final bool shuffleListWithSmileLast;
  final bool showCurrentStep;
  final bool isDarkMode;

  const LivenessDetectionViewAndroid({
    super.key,
    required this.config,
    required this.isEnableSnackBar,
    this.isDarkMode = true,
    this.showCurrentStep = false,
    this.shuffleListWithSmileLast = true,
  });

  @override
  State<LivenessDetectionViewAndroid> createState() => _LivenessDetectionViewAndroidState();
}

class _LivenessDetectionViewAndroidState extends State<LivenessDetectionViewAndroid> {
  // Camera related variables
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  int _frameCounter = 0; // Keep for debug logging only
  int _consecutiveFramesWithoutFace = 0; // Counter for tolerance
  static const int _maxFramesWithoutFaceBeforeReset = 15; // 0.5 seconds at 30fps

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _isProcessingStep = false;
  bool _faceDetectedState = false;
  static late List<LivenessDetectionStepItem> _cachedShuffledSteps;
  static bool _isShuffled = false;

  // Photo capture state
  bool _showPhotoCapturePrompt = false;
  bool _showPhotoPreview = false;
  bool _isValidatingPhoto = false;
  bool _photoValidationFailed = false;
  String? _capturedImagePath;

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
      debugPrint('\n=== ANDROID FRAME $_frameCounter DEBUG ===');
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

    // 🔍 DEBUG: Verify yPlaneBytes is really planes[0]
    if (_frameCounter % 30 == 0) {
      debugPrint('\n=== PLANE ASSIGNMENT DEBUG ===');
      debugPrint('yPlaneBytes == planes[0].bytes: ${identical(yPlaneBytes, cameraImage.planes[0].bytes)}');
      debugPrint('planes[0].bytes.length: ${cameraImage.planes[0].bytes.length}');
      debugPrint('yPlaneBytes.length: ${yPlaneBytes.length}');
    }

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
        debugPrint('Sum: ${yPlaneBytes.length} + ${uvPlaneBytes.length} = ${yPlaneBytes.length + uvPlaneBytes.length}');
      }

      // Create NV21 byte array manually (WriteBuffer adds extra bytes)
      final bytes = Uint8List(yPlaneBytes.length + uvPlaneBytes.length);
      bytes.setRange(0, yPlaneBytes.length, yPlaneBytes);
      bytes.setRange(yPlaneBytes.length, bytes.length, uvPlaneBytes);

      if (_frameCounter % 30 == 0) {
        debugPrint('Final NV21 bytes.length: ${bytes.length}');
      }

      // Verify byte array size (allow for rounding: 1382399 vs 1382400)
      final expectedSize = (cameraImage.width * cameraImage.height * 1.5).toInt();
      final sizeDiff = (bytes.length - expectedSize).abs();

      if (_frameCounter % 30 == 0) {
        debugPrint('Expected total: $expectedSize');
        if (sizeDiff > 0) {
          debugPrint('Size difference: $sizeDiff byte(s) ${sizeDiff <= 1 ? "(acceptable rounding)" : "(ERROR!)"}');
        } else {
          debugPrint('✅ Size matches perfectly!');
        }
        debugPrint('======================\n');
      }

      // Allow 1 byte difference due to rounding (1382399 vs 1382400)
      if (sizeDiff > 1) {
        debugPrint('⚠️ SIZE MISMATCH! Expected: $expectedSize, Got: ${bytes.length}, Difference: $sizeDiff');
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
      const inputImageFormat = InputImageFormat.nv21;

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
        _consecutiveFramesWithoutFace++;

        if (_frameCounter % 30 == 0) {
          debugPrint('No face detected. Consecutive frames: $_consecutiveFramesWithoutFace');
        }

        // Only reset if face is lost for multiple consecutive frames (0.5 seconds)
        if (_consecutiveFramesWithoutFace >= _maxFramesWithoutFaceBeforeReset) {
          debugPrint('⚠️ Face lost for too long - resetting steps');
          _resetSteps();
          _consecutiveFramesWithoutFace = 0; // Reset counter after resetting steps
        }

        if (mounted) setState(() => _faceDetectedState = false);
      } else {
        // Face detected - reset the lost frame counter
        _consecutiveFramesWithoutFace = 0;

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
      // Invalid metadata - just skip this frame, don't reset
      if (_frameCounter % 30 == 0) {
        debugPrint('⚠️ Invalid metadata - skipping frame');
      }
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

      if (mounted) {
        setState(() {
          _isTakingPicture = true;
          _isValidatingPhoto = true;
          _photoValidationFailed = false;
        });
      }

      await HapticFeedback.mediumImpact();
      await _cameraController?.stopImageStream();

      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) {
        _handlePhotoCaptureFailed();
        return;
      }

      final XFile? finalImage = await _compressImage(clickedImage);

      // Validate that the photo contains a face
      final bool hasFace = await _validatePhotoHasFace(finalImage);

      if (!hasFace) {
        debugPrint('Photo validation failed: No face detected in captured image');
        _handlePhotoValidationFailed();
        return;
      }

      debugPrint('Final image path: ${finalImage?.path}');

      // Show preview for user confirmation
      if (mounted) {
        setState(() {
          _capturedImagePath = finalImage?.path;
          _isValidatingPhoto = false;
          _showPhotoCapturePrompt = false;
          _showPhotoPreview = true;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _handlePhotoCaptureFailed();
    }
  }

  /// Validates that the captured photo contains a detectable face
  Future<bool> _validatePhotoHasFace(XFile? imageFile) async {
    if (imageFile == null) return false;

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await MachineLearningKitHelper.instance.processInputImage(inputImage);
      debugPrint('Photo validation: ${faces.length} face(s) detected');
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Error validating photo: $e');
      return false;
    }
  }

  /// Handles when photo capture fails
  void _handlePhotoCaptureFailed() {
    if (!mounted) return;
    setState(() {
      _isTakingPicture = false;
      _isValidatingPhoto = false;
    });
    _startLiveFeed();
  }

  /// Handles when photo validation fails (no face detected)
  void _handlePhotoValidationFailed() {
    if (!mounted) return;
    setState(() {
      _isTakingPicture = false;
      _isValidatingPhoto = false;
      _photoValidationFailed = true;
    });
  }

  /// Retry taking the photo after validation failure
  void _retryPhotoCapture() {
    if (!mounted) return;
    setState(() {
      _photoValidationFailed = false;
      _isTakingPicture = false;
      _capturedImagePath = null;
      _showPhotoPreview = false;
    });
    _startLiveFeed();
  }

  /// User confirms the captured photo
  void _confirmPhoto() {
    if (_capturedImagePath == null) return;
    _onDetectionCompleted(imgToReturn: XFile(_capturedImagePath!));
  }

  /// Shows the photo capture prompt (camera visible with take photo button)
  void _showPhotoCaptureOverlay() {
    if (!mounted) return;
    // Cancel the liveness timer since steps are complete
    _timerToDetectFace?.cancel();
    setState(() {
      _showPhotoCapturePrompt = true;
    });
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

  /// Bottom overlay with "Take Photo" button - camera remains visible
  Widget _buildPhotoCapturePrompt() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.9),
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Validation failed message
                if (_photoValidationFailed) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No face detected. Please try again.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Title
                  const Text(
                    'Take your photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position your face in the circle and tap the button',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],

                // Take Photo / Validating button
                if (_isValidatingPhoto) _buildValidatingButton() else _buildTakePhotoButton(),

                const SizedBox(height: 16),

                // Cancel button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTakePhotoButton() {
    return GestureDetector(
      onTap: _isTakingPicture ? null : _takePicture,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5A8FD4), Color(0xFFD47A9E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A8FD4).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFD47A9E).withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildValidatingButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
      ),
      child: const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  /// Photo preview screen with confirm/retake options
  Widget _buildPhotoPreview() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                  const Text(
                    'Review Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
            ),

            // Photo preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _capturedImagePath != null
                        ? Image.file(
                            File(_capturedImagePath!),
                            fit: BoxFit.contain,
                          )
                        : const SizedBox(),
                  ),
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Is this photo okay?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'We use this photo to confirm your identity and keep the platform safe. Only authorized Marriage4Life staff can access it, and it\'s never displayed publicly.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Use Photo button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF5A8FD4), Color(0xFFD47A9E)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5A8FD4).withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFFD47A9E).withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _confirmPhoto,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Use This Photo',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Retake button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _retryPhotoCapture,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.9), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Retake Photo',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show photo preview if we have a captured image
    if (_showPhotoPreview) {
      return _buildPhotoPreview();
    }

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
        // Show liveness steps OR photo capture prompt with camera
        if (!_showPhotoCapturePrompt)
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
              () => _showPhotoCaptureOverlay(),
            ),
          )
        else
          // Camera view for photo capture
          _buildPhotoCaptureCamera(),
        // Photo capture prompt overlay (bottom buttons)
        if (_showPhotoCapturePrompt && !_showPhotoPreview) _buildPhotoCapturePrompt(),
      ],
    );
  }

  /// Camera view when in photo capture mode
  Widget _buildPhotoCaptureCamera() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          SizedBox(
            height: 300,
            width: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1000),
              child: Transform.scale(
                scale: _cameraController!.value.aspectRatio,
                child: Center(
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
        ],
      ),
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
    // Android-specific head turn detection (negative angle for right turn)
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleY ?? 0) < (headTurnThreshold?.rotationAngle ?? -30)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _handlingTurnLeft({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    // Android-specific head turn detection (positive angle for left turn)
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleY ?? 0) > (headTurnThreshold?.rotationAngle ?? 30)) {
      _startProcessing();
      await _completeStep(step: step);
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
