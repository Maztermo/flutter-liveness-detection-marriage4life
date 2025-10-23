import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

class MachineLearningKitHelper {
  MachineLearningKitHelper._privateConstructor();
  static final MachineLearningKitHelper instance = MachineLearningKitHelper._privateConstructor();

  final FaceDetector faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Future<List<Face>> processInputImage(InputImage imgFile) async {
    const maxAttempts = 3;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      debugPrint('ML Kit face detection attempt ${attempt + 1}/$maxAttempts');
      final List<Face> faces = await faceDetector.processImage(imgFile);
      debugPrint('  Faces detected: ${faces.length}');
      
      if (faces.isNotEmpty) {
        debugPrint('  ✅ Face found! Bounding box: ${faces.first.boundingBox}');
        return faces;
      }
    }

    debugPrint('  ⚠️ No faces detected after $maxAttempts attempts');
    return [];
  }
}
