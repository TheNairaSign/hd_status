/// Every value here is a placeholder pending Phase 10's empirical benchmark
/// (plan §"Video compression algorithm" / §Phase 10) — none are confirmed
/// against real, current WhatsApp behavior. Keep them centralized here
/// rather than inlined so validating them later is a one-place change.
library;

/// WhatsApp's current Status per-clip duration cap. Taken from the design
/// prototype (SEGMENT_SEC), NOT independently verified.
const int kSegmentSeconds = 90;

/// Longest source video this app will attempt to split. Videos over this
/// show a blocking "too long to prepare yet" state instead of splitting.
const int kMaxSourceSeconds = 30 * 60;

/// Free-tier daily allowances (Product Brief, confirmed) / (this
/// conversation's clip-cap decision, confirmed).
const int kFreeVideosPerDay = 3;
const int kFreeClipsPerDay = 5;

/// Largest file a Free user can select at all — confirmed decision, not a
/// placeholder. Pro has no such ceiling. Binary GB (1024^3), matching how
/// Android reports file sizes.
const int kFreeMaxFileSizeBytes = 2 * 1024 * 1024 * 1024;

/// Hard ceiling applied to ALL users (including Pro) to prevent native OOM /
/// silent crash when MediaMetadataRetriever or VideoEncoder tries to open an
/// extremely large source (e.g. a full movie). 4 GB is a safe upper bound
/// — files this large are never going to produce a single WhatsApp Status
/// clip; at 1200 kbps the encode output of a 30-min video is already ~250 MB.
const int kAbsMaxFileSizeBytes = 4 * 1024 * 1024 * 1024;


/// Longest edge to send for a re-encoded image. NOT the Brief's original
/// 1920px placeholder — raised after an A/B test (2448x3264/7.9MB source)
/// showed WhatsApp Status roughly halves whatever long edge you send it,
/// capped at ~1080px: sending 1920 (halves to 960, under the cap) produced
/// a smaller final image (720x960) than sending the untouched original
/// (halves 3264 to 1632, clamped to 1080 -> 810x1080) — our own downscale
/// was landing the image in a worse WhatsApp output tier than doing
/// nothing. 2200 halves to 1100, safely clearing the ~1080 cap so our
/// output gets clamped to WhatsApp's best tier instead of proportionally
/// halved into a worse one. Based on one test image — re-validate if
/// WhatsApp's behavior looks different on other sources/devices.
const int kImageMaxDimension = 2200;

/// Video encode target profile — placeholder MVP values (Product Brief §8-style
/// starting profile), to be replaced by Phase 10 benchmark results.
class VideoEncodeProfile {
  const VideoEncodeProfile._();

  static const int maxWidth = 1080;
  static const int maxHeight = 1920;
  static const int maxFps = 30;
  static const int targetVideoKbps = 1200;
  static const int audioKbps = 128;
  static const int maxSizeBytes = 16 * 1024 * 1024; // WhatsApp's practical media ceiling
}
