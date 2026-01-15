import 'package:flutter/material.dart';

/// A gradient CTA button used throughout the app for primary actions.
///
/// Features a pink-to-blue gradient with shadows, loading state, and
/// proper disabled styling.
class GradientButton extends StatelessWidget {
  /// The button label text (required).
  final String label;

  /// Tap handler. Pass null to show disabled state.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// When true, shows a spinner and disables interaction.
  final bool isLoading;

  /// Vertical padding inside the button. Defaults to 16.
  final double verticalPadding;

  /// Horizontal padding inside the button. Defaults to 24.
  final double horizontalPadding;

  /// Border radius of the button. Defaults to 16.
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.verticalPadding = 16,
    this.horizontalPadding = 24,
    this.borderRadius = 16,
  });

  // Brand colors for gradient
  static const Color ctaBlue = Color(0xFF5A8FD4);
  static const Color ctaPink = Color(0xFFD47A9E);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isEnabled = onPressed != null && !isLoading;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: isEnabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ctaBlue, ctaPink])
            : null,
        color: isEnabled ? null : const Color(0xFFD1D5DB),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                    color: ctaBlue.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
                BoxShadow(
                    color: ctaPink.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: verticalPadding, horizontal: horizontalPadding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isEnabled
                            ? Colors.white
                            : const Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(width: 12),
                ] else if (icon != null) ...[
                  Icon(icon,
                      color:
                          isEnabled ? Colors.white : const Color(0xFF9CA3AF),
                      size: 22),
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isEnabled ? Colors.white : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
