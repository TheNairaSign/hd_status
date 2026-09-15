import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Downscale, re-encode, strip GPS EXIF, bake in orientation — the pure-Dart
/// image half of the pipeline (Product Brief: images stay in Dart, video
/// stays native). Writes into `<cacheDir>/share/`, the one directory exposed
/// through the Android FileProvider (file_provider_paths.xml), since that's
/// where every share-ready output needs to live regardless of which
/// pipeline produced it.
class ImageProcessor {
  Future<String> optimize(String sourcePath, {int maxDimension = 1920, int quality = 90}) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unreadable or unsupported image');
    }

    // Physically rotates pixels per the EXIF orientation tag, so the output
    // doesn't depend on a viewer respecting that tag — and since we build a
    // fresh JPEG below without copying the original exif block over, GPS and
    // every other EXIF field is dropped in the same step.
    var oriented = img.bakeOrientation(decoded);

    final longestEdge = oriented.width > oriented.height ? oriented.width : oriented.height;
    if (longestEdge > maxDimension) {
      oriented = oriented.width >= oriented.height
          ? img.copyResize(oriented, width: maxDimension)
          : img.copyResize(oriented, height: maxDimension);
    }

    final jpgBytes = img.encodeJpg(oriented, quality: quality);

    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'share'));
    if (!shareDir.existsSync()) shareDir.createSync(recursive: true);

    final outPath = p.join(shareDir.path, 'hd_status_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(outPath).writeAsBytes(jpgBytes);
    return outPath;
  }
}
