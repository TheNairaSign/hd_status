import 'package:flutter/services.dart';

import '../models/media_info.dart';

class MediaProbeException implements Exception {
  const MediaProbeException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Bridges to `MediaProbe.kt` — read-only metadata, no transformation.
class MediaProbeChannel {
  static const _channel = MethodChannel('com.example.hd_status/media_probe');

  Future<MediaInfo> probe(String filePath, String fileName) async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>('probe', {'filePath': filePath});
      if (raw == null) throw const MediaProbeException('No result from probe');
      return MediaInfo.fromProbeResult(raw, filePath: filePath, fileName: fileName);
    } on PlatformException catch (e) {
      throw MediaProbeException(e.message ?? 'Unreadable file');
    }
  }

  /// Real frames sampled evenly across the video, for ManualSplitScreen's
  /// timeline strip. Best-effort — returns fewer than [frameCount] (or none)
  /// on a corrupt/unreadable source rather than throwing, since a missing
  /// filmstrip shouldn't block the trim UI from working.
  Future<List<String>> filmstrip({required String filePath, required int frameCount}) async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('filmstrip', {
        'filePath': filePath,
        'frameCount': frameCount,
      });
      return (result ?? const []).cast<String>();
    } on PlatformException {
      return const [];
    }
  }
}
