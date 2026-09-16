import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../channels/image_optimizer_channel.dart';

/// Downscale, re-encode, strip GPS EXIF, bake in orientation — done
/// natively via `ImageOptimizer.kt` (BitmapFactory + Bitmap.compress),
/// not the pure-Dart `image` package this used to call. Two real wins from
/// going native: BitmapFactory's inSampleSize decodes already-downsampled
/// instead of allocating a full-resolution bitmap just to immediately
/// shrink it, and Bitmap.compress(JPEG) uses Android's native encoder
/// (Skia/libjpeg-turbo) — generally higher quality-per-byte than the pure
/// Dart encoder at the same quality setting, which was the real ceiling on
/// how far parameter tuning alone could widen the margin over WhatsApp's
/// own compression. Writes into `<cacheDir>/share/`, the one directory
/// exposed through the Android FileProvider (file_provider_paths.xml).
class ImageProcessor {
  Future<String> optimize(String sourcePath, {int maxDimension = 1920, int quality = 97}) async {
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'share'));
    if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
    final outPath = p.join(shareDir.path, 'hd_status_${DateTime.now().millisecondsSinceEpoch}.jpg');

    return ImageOptimizerChannel().optimize(
      inputPath: sourcePath,
      outputPath: outPath,
      maxDimension: maxDimension,
      quality: quality,
    );
  }
}
