/// Every value here is a placeholder pending Phase 10's empirical benchmark
/// (plan §"Video compression algorithm" / §Phase 10) — none are confirmed
/// against real, current WhatsApp behavior. Keep them centralized here
/// rather than inlined so validating them later is a one-place change.
library;

/// Length of each split clip. Deliberately SHORTER than WhatsApp's Status
/// cap (90s in the design prototype, NOT independently verified): for a
/// fixed per-clip size budget ([kSegmentTargetSizeMB]), halving or thirding
/// the duration lets the video and audio bitrates go up instead of just
/// banking the savings — 30s at 12MB gives ~3008 kbps video + 192 kbps
/// audio vs. 90s's ~938 kbps + 128 kbps. Trade-off: 3x as many clips per
/// source (more taps, and a free user's daily clip cap covers less footage).
const int kSegmentSeconds = 30;

/// Longest source video this app will attempt to split. Videos over this
/// show a blocking "too long to prepare yet" state instead of splitting.
const int kMaxSourceSeconds = 30 * 60;

/// Free-tier daily allowances (Product Brief, confirmed) / (this
/// conversation's clip-cap decision, confirmed).
const int kFreeVideosPerDay = 3;

/// TESTING ONLY — set to false before release. When true the daily video
/// cap never blocks or counts (clips are still capped).
const bool kBypassVideoCapForTesting = true;
const int kFreeClipsPerDay = 5;

/// Largest file a Free user can select at all — confirmed decision, not a
/// placeholder. Pro has no such ceiling. Binary GB (1024^3), matching how
/// Android reports file sizes.
const int kFreeMaxFileSizeBytes = 2 * 1024 * 1024 * 1024;

/// Hard ceiling applied to ALL users (including Pro) to prevent native OOM /
/// silent crash when MediaMetadataRetriever or VideoEncoder tries to open an
/// extremely large source (e.g. a full movie). 4 GB is a safe upper bound
/// — files this large are never going to produce a single WhatsApp Status
/// clip; at our target video bitrate the encode output of a 30-min video is
/// already well under 200 MB.
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

/// Our own re-encode's target OUTPUT size per segment — deliberately well
/// under [VideoEncodeProfile.maxSizeBytes] (WhatsApp's actual passthrough
/// ceiling), not equal to it. The old fixed 1200kbps target at 90s landed at
/// (1200+128)kbps × 90s / 8 ≈ 14.9MB — only a ~7% margin below the 16MB
/// cliff, with no room for VBR overshoot on a busy scene. 12MB restores a
/// real safety margin (matches the SPIT/IEEE paper's empirically-safe
/// zone). Video bitrate is DERIVED from this + segment duration (below),
/// not hardcoded, so it stays correct if segment length ever changes.
const int kSegmentTargetSizeMB = 12;

/// Video encode target profile — placeholder MVP values (Product Brief §8-style
/// starting profile), to be replaced by Phase 10 benchmark results.
class VideoEncodeProfile {
  const VideoEncodeProfile._();

  // EXPERIMENT: three real clips (848/850 long edge, all resolutions and
  // durations) show WhatsApp Status caps video at ~850 on the long edge and
  // re-encodes anything above it, even a 4.8MB file. Sending at/below that
  // ceiling tests whether WhatsApp then leaves our encode alone.
  static const int maxWidth = 480;
  static const int maxHeight = 848;
  static const int maxFps = 30;
  static const int audioKbps = 192;

  /// video_bitrate_kbps = (target_size_MB × 8000 / duration_s) − audio_kbps.
  /// Size-target-driven, not a hand-picked number — see
  /// [kSegmentTargetSizeMB]. At the current 12MB/30s/192kbps inputs this
  /// works out to ~3008 kbps (up from the old fixed 1200 kbps at 90s), with
  /// ~4MB of headroom below WhatsApp's 16MB passthrough ceiling.
  static const int targetVideoKbps = (kSegmentTargetSizeMB * 8000 ~/ kSegmentSeconds) - audioKbps;

  static const int maxSizeBytes = 16 * 1024 * 1024; // WhatsApp's practical media ceiling — passthrough gate, distinct from our own encode target above
}
