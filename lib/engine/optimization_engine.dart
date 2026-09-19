import '../models/encoding_plan.dart';
import '../models/media_info.dart';
import 'constants.dart';

/// Pure decision logic, no I/O — passthrough vs. re-encode from a probed
/// [MediaInfo], per the Product Brief's "analyze first, transform only when
/// needed" rule. Deliberately conservative: prefers passthrough whenever the
/// source already fits the target profile.
class OptimizationEngine {
  EncodingPlan plan(MediaInfo info) {
    return info.type == MediaType.image ? _planImage(info) : _planVideo(info);
  }

  EncodingPlan _planImage(MediaInfo info) {
    final longestEdge = _max(info.width ?? 0, info.height ?? 0);
    final alreadyFits = longestEdge > 0 && longestEdge <= kImageMaxDimension && info.mimeType == 'image/jpeg';
    if (alreadyFits) {
      return const EncodingPlan(
        action: EncodingAction.passthrough,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        targetVideoKbps: 0,
        reason: 'Already within the recommended size',
      );
    }
    return const EncodingPlan(
      action: EncodingAction.reencode,
      targetWidth: kImageMaxDimension,
      targetHeight: kImageMaxDimension,
      targetFps: 0,
      targetVideoKbps: 0,
      reason: 'Preparing a smaller file for WhatsApp',
    );
  }

  EncodingPlan _planVideo(MediaInfo info) {
    // The probe reports STORED dimensions plus a separate rotation flag
    // (phone-recorded portrait video is often stored landscape with a 90/270
    // tag). Media3 rotates frames upright before our Presentation effect
    // runs, so the target box must be chosen from the DISPLAY orientation —
    // otherwise a portrait clip gets a landscape target and is letterboxed
    // inside it, shrinking the real picture.
    final swapAxes = info.rotationDegrees % 180 != 0;
    final srcW = (swapAxes ? info.height : info.width) ?? 0;
    final srcH = (swapAxes ? info.width : info.height) ?? 0;
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

    final fitsBox = srcW <= boxW && srcH <= boxH;
    final isMp4 = info.mimeType == 'video/mp4';
    final underSizeCeiling = info.sizeBytes <= VideoEncodeProfile.maxSizeBytes;

    if (fitsBox && isMp4 && underSizeCeiling) {
      return const EncodingPlan(
        action: EncodingAction.passthrough,
        targetWidth: 0,
        targetHeight: 0,
        targetFps: 0,
        targetVideoKbps: 0,
        reason: 'Already optimized — no changes needed',
      );
    }

    // Fit-within-box scaling, preserving source aspect ratio, never upscaling.
    var scale = _min(boxW / srcW, boxH / srcH);
    if (scale > 1) scale = 1;
    final outW = _roundToEven((srcW * scale).round());
    final outH = _roundToEven((srcH * scale).round());

    return EncodingPlan(
      action: EncodingAction.reencode,
      targetWidth: outW,
      targetHeight: outH,
      targetFps: VideoEncodeProfile.maxFps,
      targetVideoKbps: VideoEncodeProfile.targetVideoKbps,
      reason: 'Converting for the sharpest result on WhatsApp',
    );
  }

  int _max(int a, int b) => a > b ? a : b;
  double _min(double a, double b) => a < b ? a : b;
  int _roundToEven(int v) => v.isOdd ? v - 1 : v;
}
