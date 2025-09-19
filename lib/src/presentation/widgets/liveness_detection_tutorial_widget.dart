import 'package:flutter_liveness_detection_randomized_plugin/index.dart';

class LivenessDetectionTutorialScreen extends StatefulWidget {
  final VoidCallback onStartTap;
  final bool isDarkMode;
  final int? duration;
  const LivenessDetectionTutorialScreen({super.key, required this.onStartTap, this.isDarkMode = false, required this.duration});

  @override
  State<LivenessDetectionTutorialScreen> createState() => _LivenessDetectionTutorialScreenState();
}

class _LivenessDetectionTutorialScreenState extends State<LivenessDetectionTutorialScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            const SizedBox(height: 16),
            Text(
              'Liveness Detection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: widget.isDarkMode ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 32),
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.isDarkMode ? Colors.black87 : Colors.white,
                boxShadow: !widget.isDarkMode
                    ? [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 5, blurRadius: 7, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Text(
                      '1',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    subtitle: Text(
                      "Make sure you are in an area that has sufficient lighting and that your ears are not covered",
                      style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    title: Text(
                      "Sufficient Lighting",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                  ListTile(
                    leading: Text(
                      '2',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    subtitle: Text(
                      "Hold the phone at eye level and look straight at the camera",
                      style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    title: Text(
                      "Keep phone at eye level",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                  ListTile(
                    leading: Text(
                      '3',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    subtitle: Text(
                      "You have ${widget.duration ?? 45} seconds to complete the process",
                      style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                    title: Text(
                      "Time Limit",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: () => widget.onStartTap(),
              label: const Text("I'm ready - Start"),
            ),
            const SizedBox(height: 10),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
