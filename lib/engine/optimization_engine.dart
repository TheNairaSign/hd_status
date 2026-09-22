import '../models/encoding_plan.dart';
import '../models/media_info.dart';
import 'constants.dart';

/// Pure decision logic, no I/O — passthrough vs. re-encode from a probed
/// [MediaInfo], per the Product Brief's "analyze first, transform only when
/// needed" rule.
///
/// Quality-first policy: WhatsApp recompresses everything we send it
/// regardless of our own output size (confirmed on real Status uploads —
/// see project notes), so shrinking the source before handing it over never
/// helps and sometimes hurts (two lossy passes instead of one, and less
/// detail for WhatsApp's own downscale to work from). This engine therefore
/// never reduces resolution: a source already at or above the quality floor
/// (`kImageMaxDimension` / `VideoEncodeProfile`'s box) passes through
/// untouched (or gets re-encoded at its NATIVE resolution if only the
/// container/size needs fixing); a source below the floor gets upscaled up
/// to it instead of being left as-is, so WhatsApp's own recompression has
/// as much real detail to draw from as possible.
class OptimizationEngine {
  EncodingPlan plan(MediaInfo info) {
    return info.type == MediaType.image ? _planImage(info) : _planVideo(info);
  }

  EncodingPlan _planImage(MediaInfo info) {
    final srcW = info.width ?? 0;
    final srcH = info.height ?? 0;
    final longestEdge = _max(srcW, srcH);
    final meetsQualityFloor = longestEdge >= kImageMaxDimension;

    if (meetsQualityFloor && info.mimeType == 'image/jpeg') {
      return const EncodingPlan(
        action: EncodingAction.passthrough,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        targetVideoKbps: 0,
        reason: 'Already the best quality we can send',
      );
    }

    if (meetsQualityFloor) {
      // Already good enough — just needs re-encoding (format/EXIF), not resizing.
      return EncodingPlan(
        action: EncodingAction.reencode,
        targetWidth: srcW,
        targetHeight: srcH,
        targetFps: 0,
        targetVideoKbps: 0,
        reason: 'Preparing the best quality we can send',
      );
    }

    // Below the floor — upscale up to it, preserving aspect ratio.
    final scale = longestEdge > 0 ? kImageMaxDimension / longestEdge : 1.0;
    final outW = srcW > 0 ? (srcW * scale).round() : kImageMaxDimension;
    final outH = srcH > 0 ? (srcH * scale).round() : kImageMaxDimension;
    return EncodingPlan(
      action: EncodingAction.reencode,
      targetWidth: outW,
      targetHeight: outH,
      targetFps: 0,
      targetVideoKbps: 0,
      reason: 'Enhancing to the best quality we can send',
    );
  }

  EncodingPlan _planVideo(MediaInfo info) {
    final srcW = info.width ?? 0;
    final srcH = info.height ?? 0;
    if (srcW <= 0 || srcH <= 0) {
      // Missing dimensions — can't reason about fit, so re-encode defensively.
      return const EncodingPlan(
        action: EncodingAction.reencode,
        targetWidth: VideoEncodeProfile.maxWidth,
        targetHeight: VideoEncodeProfile.maxHeight,
        targetFps: VideoEncodeProfile.maxFps,
        targetVideoKbps: VideoEncodeProfile.targetVideoKbps,
        reason: 'Preparing your video',
      );
    }

    final portrait = srcH >= srcW;
    final boxW = portrait ? VideoEncodeProfile.maxWidth : VideoEncodeProfile.maxHeight;
    final boxH = portrait ? VideoEncodeProfile.maxHeight : VideoEncodeProfile.maxWidth;

    final meetsQualityFloor = srcW >= boxW && srcH >= boxH;
    final isMp4 = info.mimeType == 'video/mp4';
    final underSizeCeiling = info.sizeBytes <= VideoEncodeProfile.maxSizeBytes;

    if (meetsQualityFloor && isMp4 && underSizeCeiling) {
      return const EncodingPlan(
        action: EncodingAction.passthrough,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        targetVideoKbps: 0,
        reason: 'Already optimized — no changes needed',
      );
    }

    if (meetsQualityFloor) {
      // Resolution's already at or above the floor — only the container/size
      // needs fixing, so re-encode at the NATIVE resolution, no resize.
      return EncodingPlan(
        action: EncodingAction.reencode,
        targetWidth: srcW,
        targetHeight: srcH,
        targetFps: VideoEncodeProfile.maxFps,
        targetVideoKbps: VideoEncodeProfile.targetVideoKbps,
        reason: 'Converting for the sharpest result on WhatsApp',
      );
    }

    // Below the floor in at least one axis — cover-scale (not contain-scale)
    // so BOTH output dimensions reach at least the box, preserving aspect
    // ratio. Using max() here (not min(), which the old downscale-only
    // "contain" logic used) is what makes this an upscale-to-floor instead
    // of a shrink-to-fit.
    final scale = _max2(boxW / srcW, boxH / srcH);
    final outW = _roundToEven((srcW * scale).round());
    final outH = _roundToEven((srcH * scale).round());

    return EncodingPlan(
      action: EncodingAction.reencode,
      targetWidth: outW,
      targetHeight: outH,
      targetFps: VideoEncodeProfile.maxFps,
      targetVideoKbps: VideoEncodeProfile.targetVideoKbps,
      reason: 'Enhancing for the sharpest result on WhatsApp',
    );
  }

  int _max(int a, int b) => a > b ? a : b;
  double _max2(double a, double b) => a > b ? a : b;
  int _roundToEven(int v) => v.isOdd ? v - 1 : v;
}
