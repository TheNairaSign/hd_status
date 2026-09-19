import 'package:flutter/services.dart';

abstract class EncodeEvent {}

class EncodeProgress extends EncodeEvent {
  EncodeProgress(this.progress);
  final double progress;
}

class EncodeCompleted extends EncodeEvent {
  EncodeCompleted(this.outputPath);
  final String outputPath;
}

class EncodeError extends EncodeEvent {
  EncodeError(this.message);
  final String message;
}

/// Bridges to `VideoEncoder.kt`. One job at a time — starting a new encode
/// implicitly cancels any in-flight one, matching the native side.
class VideoEncoderChannel {
  static const _method = MethodChannel('com.example.hd_status/video_encoder');
  static const _events = EventChannel('com.example.hd_status/video_encoder_events');

  Stream<EncodeEvent> get events => _events.receiveBroadcastStream().map((raw) {
        final map = Map<Object?, Object?>.from(raw as Map);
        switch (map['type']) {
          case 'progress':
            return EncodeProgress((map['progress'] as num).toDouble());
          case 'completed':
            return EncodeCompleted(map['outputPath'] as String);
          case 'error':
            return EncodeError(map['message'] as String? ?? 'Encode failed');
          default:
            return EncodeError('Unknown event: ${map['type']}');
        }
      });

  /// [targetWidth]/[targetHeight] 0 means no resize. [targetVideoKbps] <= 0
  /// means let the platform encoder pick its own default bitrate for the
  /// resolution instead of requesting one explicitly; [audioKbps] <= 0 keeps
  /// the encoder's default audio bitrate. [startMs]/[endMs] -1
  /// means no trim (the whole file) — non-default values are how the
  /// segment splitter (Phase 6) cuts one clip per encode pass.
  ///
  /// No fps-cap parameter: VideoEncoder.kt doesn't enforce one yet (see its
  /// class doc's KNOWN GAP note) — a fps parameter here would silently do
  /// nothing on the native side, so it's left out rather than imply it works.
  Future<void> startEncode({
    required String inputPath,
    required String outputPath,
    int targetWidth = 0,
    int targetHeight = 0,
    int targetVideoKbps = 0,
    int audioKbps = 0,
    int startMs = -1,
    int endMs = -1,
  }) {
    return _method.invokeMethod('startEncode', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'targetVideoKbps': targetVideoKbps,
      'audioKbps': audioKbps,
      'startMs': startMs,
      'endMs': endMs,
    });
  }

  Future<void> cancelEncode() => _method.invokeMethod('cancelEncode');
}
