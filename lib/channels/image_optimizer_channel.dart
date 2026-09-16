import 'package:flutter/services.dart';

/// Bridges to `ImageOptimizer.kt` — native BitmapFactory decode/resize +
/// Bitmap.compress(JPEG) encode, replacing the earlier pure-Dart `image`
/// package pipeline (see image_processor.dart's class doc for why).
class ImageOptimizerChannel {
  static const _channel = MethodChannel('com.example.hd_status/image_optimizer');

  Future<String> optimize({
    required String inputPath,
    required String outputPath,
    required int maxDimension,
    required int quality,
  }) async {
    final result = await _channel.invokeMethod<String>('optimize', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'maxDimension': maxDimension,
      'quality': quality,
    });
    if (result == null) {
      throw const FormatException('No output path returned from the native image optimizer');
    }
    return result;
  }
}
