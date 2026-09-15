import 'package:flutter/material.dart';

/// Compact header mark — a placeholder for the real app icon asset. Swap
/// the inner shape for the actual logo when one exists.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: BoxDecoration(
            color: colorScheme.onPrimary,
            borderRadius: BorderRadius.circular(size * 0.12),
          ),
        ),
      ),
    );
  }
}
