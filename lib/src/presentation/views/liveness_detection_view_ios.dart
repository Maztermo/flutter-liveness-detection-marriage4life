// ignore_for_file: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_liveness_detection_randomized_plugin/index.dart';
import 'package:flutter_liveness_detection_randomized_plugin/src/core/constants/liveness_detection_step_constant.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

List<CameraDescription> availableCams = [];

class LivenessDetectionViewIOS extends StatefulWidget {
  final LivenessDetectionConfig config;
  final bool isEnableSnackBar;
  final bool shuffleListWithSmileLast;
  final bool showCurrentStep;
  final bool isDarkMode;

  const LivenessDetectionViewIOS({
    super.key,
    required this.config,
    required this.isEnableSnackBar,
    this.isDarkMode = true,
    this.showCurrentStep = false,
    this.shuffleListWithSmileLast = true,
  });

  @override
  State<LivenessDetectionViewIOS> createState() => _LivenessDetectionViewIOSState();
}

class _LivenessDetectionViewIOSState extends State<LivenessDetectionViewIOS> {
  // Camera related variables
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _isProcessingStep = false;
  bool _faceDetectedState = false;
  static late List<LivenessDetectionStepItem> _cachedShuffledSteps;
  static bool _isShuffled = false;

  // Photo capture overlay state
  bool _showPhotoCaptureScreen = false;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  bool _showRetryScreen = false;
  bool _isValidatingPhoto = false;

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
    _countdownTimer?.cancel();
    _countdownTimer = null;
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
      imageFormatGroup: ImageFormatGroup.bgra8888, // iOS uses BGRA8888 format
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
    final camera = availableCams[_cameraIndex];
    final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (imageRotation == null) return;

    InputImage? inputImage;

    // iOS-specific image processing with BGRA8888 format
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      inputImage = InputImage.fromBytes(
        bytes: cameraImage.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: imageRotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        ),
      );
    }

    if (inputImage != null) {
      _processImage(inputImage);
    }
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (_isBusy) return;
    _isBusy = true;

    final faces = await MachineLearningKitHelper.instance.processInputImage(inputImage);

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

      if (mounted) {
        setState(() {
          _isTakingPicture = true;
          _isValidatingPhoto = true;
        });
      }
      await _cameraController?.stopImageStream();

      final XFile? clickedImage = await _cameraController?.takePicture();
      if (clickedImage == null) {
        _handlePhotoValidationFailed();
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
      _onDetectionCompleted(imgToReturn: finalImage);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      _handlePhotoValidationFailed();
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

  /// Handles when photo validation fails (no face detected)
  void _handlePhotoValidationFailed() {
    if (!mounted) return;
    setState(() {
      _isTakingPicture = false;
      _isValidatingPhoto = false;
      _showPhotoCaptureScreen = false;
      _showRetryScreen = true;
    });
  }

  /// Retry taking the photo after validation failure
  void _retryPhotoCapture() {
    if (!mounted) return;
    setState(() {
      _showRetryScreen = false;
      _isTakingPicture = false;
    });
    _startLiveFeed();
    // Show the countdown overlay again after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showPhotoCaptureOverlay();
    });
  }

  /// Shows the photo capture screen with countdown
  void _showPhotoCaptureOverlay() {
    if (!mounted) return;
    setState(() {
      _showPhotoCaptureScreen = true;
      _countdownValue = 3;
    });
    _startCountdown();
  }

  /// Starts the 3-second countdown
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        timer.cancel();
        _takePicture();
      } else {
        HapticFeedback.lightImpact();
        setState(() => _countdownValue--);
      }
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

  Widget _buildPhotoCaptureOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  onPressed: () {
                    _countdownTimer?.cancel();
                    Navigator.of(context).pop(null);
                  },
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Camera icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5A8FD4).withValues(alpha: 0.3),
                    const Color(0xFFD47A9E).withValues(alpha: 0.3),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 40),

            // Title
            const Text(
              'Get ready for your photo!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Look at the camera and smile',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            // Countdown number or validating indicator
            if (_isValidatingPhoto)
              _buildValidatingIndicator()
            else
              _buildCountdownCircle(),

            const Spacer(flex: 3),

            // Tip at bottom
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Make sure your face is clearly visible and well-lit',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCircle() {
    return Container(
      width: 100,
      height: 100,
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
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFD47A9E).withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Text(
            '$_countdownValue',
            key: ValueKey<int>(_countdownValue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidatingIndicator() {
    return Column(
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Validating photo...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRetryOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Close button
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Error icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.face_retouching_off,
                size: 56,
                color: Color(0xFFEF4444),
              ),
            ),

            const SizedBox(height: 40),

            // Title
            const Text(
              'No face detected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'We couldn\'t detect a face in the photo. Please try again with better lighting.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(flex: 2),

            // Retry button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
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
                      onTap: _retryPhotoCapture,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        child: Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

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

            const Spacer(),
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
            () => _showPhotoCaptureOverlay(),
          ),
        ),
        // Photo capture countdown overlay
        if (_showPhotoCaptureScreen) _buildPhotoCaptureOverlay(),
        // Retry overlay when face validation fails
        if (_showRetryScreen) _buildRetryOverlay(),
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
    // iOS-specific head turn detection (positive angle for right turn)
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleY ?? 0) > (headTurnThreshold?.rotationAngle ?? 30)) {
      _startProcessing();
      await _completeStep(step: step);
    }
  }

  Future<void> _handlingTurnLeft({
    required Face face,
    required LivenessDetectionStep step,
  }) async {
    // iOS-specific head turn detection (negative angle for left turn)
    final headTurnThreshold = FlutterLivenessDetectionRandomizedPlugin.instance.thresholdConfig
        .firstWhereOrNull((p0) => p0 is LivenessThresholdHead) as LivenessThresholdHead?;
    if ((face.headEulerAngleY ?? 0) < (headTurnThreshold?.rotationAngle ?? -30)) {
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
