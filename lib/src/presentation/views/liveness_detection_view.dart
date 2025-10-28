// ignore_for_file: depend_on_referenced_packages
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_liveness_detection_randomized_plugin/src/models/liveness_detection_config.dart';
import 'package:flutter_liveness_detection_randomized_plugin/src/presentation/views/liveness_detection_view_android.dart';
import 'package:flutter_liveness_detection_randomized_plugin/src/presentation/views/liveness_detection_view_ios.dart';

/// Platform-agnostic liveness detection view that automatically routes to
/// the correct platform-specific implementation.
///
/// This wrapper allows for independent Android and iOS implementations,
/// preventing changes in one platform from affecting the other.
class LivenessDetectionView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Route to platform-specific implementation
    if (Platform.isAndroid) {
      return LivenessDetectionViewAndroid(
        config: config,
        isEnableSnackBar: isEnableSnackBar,
        isDarkMode: isDarkMode,
        showCurrentStep: showCurrentStep,
        shuffleListWithSmileLast: shuffleListWithSmileLast,
      );
    } else if (Platform.isIOS) {
      return LivenessDetectionViewIOS(
        config: config,
        isEnableSnackBar: isEnableSnackBar,
        isDarkMode: isDarkMode,
        showCurrentStep: showCurrentStep,
        shuffleListWithSmileLast: shuffleListWithSmileLast,
      );
    } else {
      // Fallback for unsupported platforms
      return const Center(
        child: Text(
          'Liveness detection is not supported on this platform',
          textAlign: TextAlign.center,
        ),
      );
    }
  }
}
