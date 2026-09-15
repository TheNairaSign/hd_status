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
}
