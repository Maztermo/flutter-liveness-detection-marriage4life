# Liveness Detection Fork - Photo Capture Screen Changes

This document contains the exact code changes needed for the `flutter-liveness-detection-marriage4life` fork to add a proper photo capture screen before taking the verification photo.

## Overview

**Current behavior**: After completing all liveness steps, a photo is taken immediately after a 500ms delay with no prior notice.

**New behavior**: After completing all liveness steps, show a "Get Ready" screen with a 3-second countdown, then take the photo.

## Files to Modify

Both platform-specific implementations need the same changes:

1. `lib/src/presentation/views/liveness_detection_view_android.dart`
2. `lib/src/presentation/views/liveness_detection_view_ios.dart`

---

## Step 1: Add State Variables

Add these new state variables to the `State` class (around line 33-50):

```dart
// Add after existing state variables
bool _showPhotoCaptureScreen = false;
int _countdownValue = 3;
Timer? _countdownTimer;
```

---

## Step 2: Add Dispose Cleanup

In the `dispose()` method, add cleanup for the countdown timer:

```dart
@override
void dispose() {
  _timerToDetectFace?.cancel();
  _timerToDetectFace = null;
  _countdownTimer?.cancel();  // ADD THIS LINE
  _countdownTimer = null;     // ADD THIS LINE
  _cameraController?.dispose();
  // ... rest of existing dispose code
}
```

---

## Step 3: Add Photo Capture Methods

Add these methods after the `_takePicture()` method:

```dart
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
      setState(() => _countdownValue--);
    }
  });
}
```

---

## Step 4: Create Photo Capture Overlay Widget

Add this widget method (place it near the end of the class, before the step handling methods):

```dart
Widget _buildPhotoCaptureOverlay() {
  return Container(
    color: Colors.black.withValues(alpha: 0.85),
    child: SafeArea(
      child: Column(
        children: [
          // Close button (optional - allows cancel)
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
          
          // Countdown number
          Container(
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
          ),
          
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
```

---

## Step 5: Modify the onCompleted Callback

In the `_buildDetectionBody()` method, find the `LivenessDetectionStepOverlayWidget` and change the `onCompleted` callback:

**Before:**
```dart
onCompleted: () => Future.delayed(
  const Duration(milliseconds: 500),
  () => _takePicture(),
),
```

**After:**
```dart
onCompleted: () => Future.delayed(
  const Duration(milliseconds: 500),
  () => _showPhotoCaptureOverlay(),
),
```

---

## Step 6: Add Overlay to Detection Body Stack

Modify `_buildDetectionBody()` to show the overlay when needed:

**Before:**
```dart
return Stack(
  children: [
    Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      color: widget.isDarkMode ? Colors.black : Colors.white,
    ),
    LivenessDetectionStepOverlayWidget(
      // ... existing props
    ),
  ],
);
```

**After:**
```dart
return Stack(
  children: [
    Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      color: widget.isDarkMode ? Colors.black : Colors.white,
    ),
    LivenessDetectionStepOverlayWidget(
      // ... existing props
    ),
    // Photo capture overlay
    if (_showPhotoCaptureScreen) _buildPhotoCaptureOverlay(),
  ],
);
```

---

## Complete Example (Android)

Here's the complete diff for the Android file. The iOS file follows the same pattern.

### State class changes:

```diff
class _LivenessDetectionViewAndroidState extends State<LivenessDetectionViewAndroid> {
  // Camera related variables
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isBusy = false;
  bool _isTakingPicture = false;
  Timer? _timerToDetectFace;
  int _frameCounter = 0;
  int _consecutiveFramesWithoutFace = 0;
  static const int _maxFramesWithoutFaceBeforeReset = 15;

  // Detection state variables
  late bool _isInfoStepCompleted;
  bool _isProcessingStep = false;
  bool _faceDetectedState = false;
  static late List<LivenessDetectionStepItem> _cachedShuffledSteps;
  static bool _isShuffled = false;

+ // Photo capture overlay state
+ bool _showPhotoCaptureScreen = false;
+ int _countdownValue = 3;
+ Timer? _countdownTimer;
```

### Dispose method:

```diff
@override
void dispose() {
  _timerToDetectFace?.cancel();
  _timerToDetectFace = null;
+ _countdownTimer?.cancel();
+ _countdownTimer = null;
  _cameraController?.dispose();
  // ... rest
}
```

---

## Testing Checklist

After making these changes:

- [ ] Test on Android device - all liveness steps complete
- [ ] Verify countdown overlay appears after final step
- [ ] Verify countdown animates 3 → 2 → 1
- [ ] Verify photo is taken after countdown
- [ ] Verify photo path is returned correctly
- [ ] Test cancel (X) button on overlay
- [ ] Repeat all tests on iOS device

---

## Notes

1. **Haptic Feedback**: Consider adding haptic feedback on each countdown tick:
   ```dart
   HapticFeedback.lightImpact();
   ```

2. **Sound Effect**: You could add a camera shutter sound when taking the photo.

3. **Flash Effect**: Consider adding a white flash overlay when the photo is captured.

4. **Localization**: The strings are hardcoded. For full localization support, you'd need to pass these as configuration options.
