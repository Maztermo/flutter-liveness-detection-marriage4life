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
  // Brand colors from style guide
  static const Color ctaBlue = Color(0xFF5A8FD4);
  static const Color ctaPink = Color(0xFFD47A9E);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDarkMode ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = widget.isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF374151);

    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.black : const Color(0xFFFAFAFA),
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Close button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(null),
                icon: Icon(
                  Icons.close,
                  color: widget.isDarkMode ? Colors.white70 : const Color(0xFF6B7280),
                  size: 28,
                ),
              ),
            ),

            const Spacer(),

            // Face icon with gradient background
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ctaBlue.withValues(alpha: 0.2),
                    ctaPink.withValues(alpha: 0.2),
                  ],
                ),
                border: Border.all(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : ctaBlue.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.face_retouching_natural,
                size: 48,
                color: widget.isDarkMode ? Colors.white : ctaBlue,
              ),
            ),

            const SizedBox(height: 32),

            // Title
            Text(
              'Liveness Detection',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 24,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Follow the instructions to verify your identity',
              style: TextStyle(
                fontSize: 16,
                color: textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Instructions card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                border: Border.all(
                  color: widget.isDarkMode
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: !widget.isDarkMode
                    ? [
                        BoxShadow(
                          color: const Color(0x14000000),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  _buildInstructionItem(
                    icon: Icons.lightbulb_outline,
                    title: "Good Lighting",
                    subtitle: "Make sure you are in an area with sufficient lighting",
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionItem(
                    icon: Icons.phone_android,
                    title: "Phone at Eye Level",
                    subtitle: "Hold the phone at eye level and look straight at the camera",
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionItem(
                    icon: Icons.timer_outlined,
                    title: "Time Limit",
                    subtitle: "You have ${widget.duration ?? 45} seconds to complete the process",
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Start button
            GradientButton(
              label: "I'm Ready - Start",
              icon: Icons.camera_alt_outlined,
              onPressed: widget.onStartTap,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ctaBlue.withValues(alpha: 0.15),
                ctaPink.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: widget.isDarkMode ? Colors.white : ctaBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
