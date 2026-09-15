enum EncodingAction { passthrough, reencode }

class EncodingPlan {
  const EncodingPlan({
    required this.action,
    required this.targetWidth,
    required this.targetHeight,
    required this.targetFps,
    required this.targetVideoKbps,
    required this.reason,
  });

  final EncodingAction action;

  /// 0 when [action] is passthrough (no target — output is the input).
  final int targetWidth;
  final int targetHeight;
  final int targetFps;
  final int targetVideoKbps;

  /// Plain-language reason shown on the Selected-media screen, e.g.
  /// "Preparing a smaller file for WhatsApp" / "Already optimized".
  final String reason;
}
