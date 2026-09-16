import 'package:flutter/material.dart';

/// The single primary action for a screen (Choose media, Optimize, Share…).
/// Design principle: one primary action per view — reach for this widget
/// instead of styling an ad-hoc [ElevatedButton] so that rule stays visible
/// in the code, not just the design.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner and ignores taps. Set this the instant a long-running
  /// action starts (e.g. before awaiting image_picker) rather than only
  /// after it returns — some of that wait happens inside a plugin's native
  /// call, where Dart has no hook to show anything else, so this button
  /// being visibly busy is the only feedback available for that stretch.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (loading) {
      child = const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
    } else if (icon == null) {
      child = Text(label);
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          )
        ),
        onPressed: loading ? null : onPressed, child: child),
    );
  }
}

/// A lower-emphasis action alongside a [PrimaryButton] (e.g. "Not now",
/// "Choose an image"). Never styled as filled — that's reserved for the
/// single primary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}
