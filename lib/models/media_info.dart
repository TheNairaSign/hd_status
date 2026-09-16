import '../engine/constants.dart';

enum MediaType { image, video }

class MediaInfo {
  const MediaInfo({
    required this.filePath,
    required this.fileName,
    required this.type,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.duration,
    required this.rotationDegrees,
    required this.sizeBytes,
    this.thumbnailPath,
  });

  factory MediaInfo.fromProbeResult(
    Map<Object?, Object?> raw, {
    required String filePath,
    required String fileName,
  }) {
    final typeStr = raw['type'] as String?;
    final durationMs = (raw['durationMs'] as num?)?.toInt();
    return MediaInfo(
      filePath: filePath,
      fileName: fileName,
      type: typeStr == 'video' ? MediaType.video : MediaType.image,
      mimeType: raw['mimeType'] as String?,
      width: (raw['width'] as num?)?.toInt(),
      height: (raw['height'] as num?)?.toInt(),
      duration: durationMs == null ? null : Duration(milliseconds: durationMs),
      rotationDegrees: (raw['rotationDegrees'] as num?)?.toInt() ?? 0,
      sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
      thumbnailPath: raw['thumbnailPath'] as String?,
    );
  }

  final String filePath;
  final String fileName;
  final MediaType type;
  final String? mimeType;
  final int? width;
  final int? height;
  final Duration? duration;
  final int rotationDegrees;
  final int sizeBytes;
  final String? thumbnailPath;

  /// Duration exceeds a single WhatsApp Status clip — needs the
  /// Long video → Splitting → Clips ready path instead of a single Optimize.
  bool get needsSplitting =>
      type == MediaType.video && (duration?.inSeconds ?? 0) > kSegmentSeconds;

  /// Longer than this app will attempt to split at all.
  bool get exceedsMaxSourceDuration =>
      type == MediaType.video && (duration?.inSeconds ?? 0) > kMaxSourceSeconds;

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1)}MB';
    return '${(sizeBytes / 1024).toStringAsFixed(0)}KB';
  }

  String get dimensionsLabel => (width != null && height != null) ? '$width×$height' : '';

  String get durationLabel {
    final d = duration;
    if (d == null) return '';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Plain-language summary line per the UX Guide's "1080×1920 · 22MB" style.
  String get summaryLabel {
    final parts = <String>[
      if (dimensionsLabel.isNotEmpty) dimensionsLabel,
      if (durationLabel.isNotEmpty) durationLabel,
      sizeLabel,
    ];
    return parts.join(' · ');
  }
}
