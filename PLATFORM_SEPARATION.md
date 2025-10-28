# Platform-Specific Liveness Detection Implementation

This document explains the platform-specific separation implemented for liveness detection to allow independent development for Android and iOS.

## Overview

The liveness detection feature has been split into three files:

1. **`liveness_detection_view.dart`** - Platform-agnostic wrapper that routes to the correct implementation
2. **`liveness_detection_view_android.dart`** - Android-specific implementation with NV21 image format
3. **`liveness_detection_view_ios.dart`** - iOS-specific implementation with BGRA8888 image format (based on original upstream code)

## Why This Separation?

The Android version required extensive modifications to work with the NV21 image format, including:

- Complex byte array construction combining Y and UV planes
- Detailed debug logging for troubleshooting
- Frame tolerance for face detection
- Platform-specific head turn angle detection

These modifications broke iOS compatibility. By separating the implementations, you can now:

- ✅ Maintain Android-specific fixes without affecting iOS
- ✅ Keep iOS using the proven original implementation
- ✅ Test and modify each platform independently
- ✅ Update one platform without worrying about breaking the other

## File Breakdown

### 1. Platform Router (`liveness_detection_view.dart`)

This is a simple wrapper that detects the platform and routes to the correct implementation:

```dart
if (Platform.isAndroid) {
  return LivenessDetectionViewAndroid(...);
} else if (Platform.isIOS) {
  return LivenessDetectionViewIOS(...);
}
```

**This file should rarely need changes** - it just forwards parameters to the platform-specific views.

### 2. Android Implementation (`liveness_detection_view_android.dart`)

This contains your current working Android code with:

- **NV21 image format handling** - Manually constructs byte arrays from Y and UV planes
- **Extensive debug logging** - Frame-by-frame diagnostics (every 30 frames)
- **Frame tolerance** - Allows 15 consecutive frames without face before reset (0.5 seconds)
- **Android-specific angles**:
  - Look Right: `headEulerAngleY < -30`
  - Look Left: `headEulerAngleY > 30`

**Key sections for Android development:**

- `_processCameraImage()` (lines 267-388) - Complex NV21 byte processing
- `_handlingTurnRight()` / `_handlingTurnLeft()` - Android angle logic

### 3. iOS Implementation (`liveness_detection_view_ios.dart`)

This uses the **original upstream implementation** from `bagussubagja/flutter-liveness-detection-randomized-plugin`:

- **BGRA8888 image format** - Simple single-plane byte array
- **Minimal processing** - Direct plane[0].bytes usage
- **iOS-specific angles** (opposite of Android):
  - Look Right: `headEulerAngleY > 30`
  - Look Left: `headEulerAngleY < -30`

**Key sections for iOS development:**

- `_processCameraImage()` (lines 260-283) - Simple BGRA8888 processing
- `_handlingTurnRight()` / `_handlingTurnLeft()` - iOS angle logic

## Usage

No changes needed in your app code! The API remains identical:

```dart
LivenessDetectionView(
  config: LivenessDetectionConfig(...),
  isEnableSnackBar: true,
  isDarkMode: true,
  showCurrentStep: false,
  shuffleListWithSmileLast: true,
)
```

The platform detection happens automatically inside.

## Development Workflow

### Modifying Android Code

1. Edit **`liveness_detection_view_android.dart`**
2. Test on Android devices
3. iOS remains unaffected ✅

### Modifying iOS Code

1. Edit **`liveness_detection_view_ios.dart`**
2. Test on iOS devices
3. Android remains unaffected ✅

### Modifying Common Behavior

If you need to change behavior that affects **both platforms**:

1. Make the change in **both** files (Android and iOS)
2. Test on **both platforms**
3. Consider if the logic should differ between platforms

## Key Differences Between Platforms

| Feature                 | Android                 | iOS                   |
| ----------------------- | ----------------------- | --------------------- |
| **Image Format**        | NV21 (semi-planar YUV)  | BGRA8888 (packed)     |
| **Byte Processing**     | Complex (Y + UV planes) | Simple (single plane) |
| **Head Turn (Right)**   | `angle < -30`           | `angle > 30`          |
| **Head Turn (Left)**    | `angle > 30`            | `angle < -30`         |
| **Debug Logging**       | Extensive               | Minimal               |
| **Face Loss Tolerance** | 15 frames (~0.5s)       | Immediate reset       |

## Troubleshooting

### Android Issues

**Location**: `liveness_detection_view_android.dart`

- Check debug logs (every 30 frames)
- Verify NV21 byte array size matches expected: `width × height × 1.5`
- Check plane[0].bytesPerPixel == 1 and plane[1].bytesPerPixel == 2

### iOS Issues

**Location**: `liveness_detection_view_ios.dart`

- Verify camera format is BGRA8888
- Check imageRotation is not null
- Ensure plane[0] bytes are being read correctly

### Both Platforms

- Verify ML Kit face detection is working
- Check threshold configurations
- Ensure camera permissions are granted

## Syncing with Upstream

If you want to pull updates from the original repository:

```bash
git fetch upstream
```

For iOS updates:

1. Check changes to `liveness_detection_view.dart` in upstream
2. Apply relevant changes to `liveness_detection_view_ios.dart`

For Android updates:

1. You're already significantly diverged
2. Evaluate if upstream changes are needed
3. Carefully merge only beneficial changes

## Testing Checklist

Before committing changes:

- [ ] Test Android on multiple devices
- [ ] Test iOS on multiple devices
- [ ] Verify all liveness steps work (blink, look left/right/up/down, smile)
- [ ] Check image quality and compression
- [ ] Test with different lighting conditions
- [ ] Verify timeout behavior
- [ ] Test face detection reset on face loss

## Technical Notes

### Why NV21 for Android?

Android cameras typically output NV21 format (semi-planar YUV):

- Plane 0: Y (luminance) data
- Plane 1: Interleaved UV (chrominance) data

The Android implementation concatenates these planes for ML Kit.

### Why BGRA8888 for iOS?

iOS cameras output BGRA8888 format (packed):

- All color channels in a single plane
- 4 bytes per pixel (Blue, Green, Red, Alpha)

This is simpler to process - just pass plane[0] bytes directly.

### Angle Differences

The coordinate system is mirrored between platforms due to different camera orientations and processing pipelines. This is why head turn angles are opposite.

## Future Improvements

Consider adding:

- [ ] Configurable debug logging level per platform
- [ ] Platform-specific threshold configurations
- [ ] Performance metrics comparison
- [ ] Automated platform-specific testing

## Support

For Android-specific issues: Check `liveness_detection_view_android.dart`  
For iOS-specific issues: Check `liveness_detection_view_ios.dart`  
For general issues: Check `liveness_detection_view.dart` routing logic

---

**Last Updated**: October 28, 2025  
**Based On**:

- Android: Custom NV21 implementation
- iOS: Original `bagussubagja/flutter-liveness-detection-randomized-plugin` (upstream/master)
