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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          );
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: onPressed, child: child),
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
