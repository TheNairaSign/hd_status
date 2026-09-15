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
