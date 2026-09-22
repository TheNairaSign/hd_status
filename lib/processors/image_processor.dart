import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/constants.dart';

/// Upscale-if-needed, re-encode, strip GPS EXIF, bake in orientation — the
/// pure-Dart image half of the pipeline (Product Brief: images stay in
/// Dart, video stays native). Writes into `<cacheDir>/share/`, the one
/// directory exposed through the Android FileProvider
/// (file_provider_paths.xml), since that's where every share-ready output
/// needs to live regardless of which pipeline produced it.
///
/// Never downscales: WhatsApp recompresses whatever it receives regardless
/// of our output size, so shrinking below [_ImageJob.maxDimension] only
/// throws away detail WhatsApp's own pass could have used, for no benefit.
/// A source already at or above that floor is left at its native
/// resolution; one below it is upscaled up to the floor instead.
class ImageProcessor {
  Future<String> optimize(String sourcePath, {int maxDimension = kImageMaxDimension, int quality = 97}) async {
    // Path is resolved here (needs the path_provider plugin channel, which
    // only works reliably on the root isolate) and handed to the isolate as
    // a plain string — the actual decode/resize/encode below is pure Dart +
    // dart:io, which is why it's safe to run via compute().
    final tempDir = await getTemporaryDirectory();
    final shareDir = Directory(p.join(tempDir.path, 'share'));
    if (!shareDir.existsSync()) shareDir.createSync(recursive: true);
    final outPath = p.join(shareDir.path, 'hd_status_${DateTime.now().millisecondsSinceEpoch}.jpg');

    return compute(
      _processImage,
      _ImageJob(sourcePath: sourcePath, outputPath: outPath, maxDimension: maxDimension, quality: quality),
    );
  }
}

class _ImageJob {
  const _ImageJob({
    required this.sourcePath,
    required this.outputPath,
    required this.maxDimension,
    required this.quality,
  });

  final String sourcePath;
  final String outputPath;
  final int maxDimension;
  final int quality;
}

/// Runs on a background isolate via [compute]. Decoding a real phone photo
/// (often 4000px+) into a raw pixel buffer, then box-filtering it down to
/// [_ImageJob.maxDimension], is real CPU/memory work — running it
/// synchronously on the UI isolate froze the app's animations and risked
/// Android's ANR watchdog on larger sources, which is what looked like a
/// crash. Must be a top-level function (not a closure) for `compute` to
/// hand it to another isolate.
String _processImage(_ImageJob job) {
  final bytes = File(job.sourcePath).readAsBytesSync();
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
  if (longestEdge < job.maxDimension) {
    // `cubic` is the best upsampling filter this package offers (no true
    // Lanczos available) — `average`'s box filter is for downscaling and
    // would just blur an upscale; nearest-neighbor (the `copyResize`
    // default) would look blocky.
    oriented = oriented.width >= oriented.height
        ? img.copyResize(oriented, width: job.maxDimension, interpolation: img.Interpolation.cubic)
        : img.copyResize(oriented, height: job.maxDimension, interpolation: img.Interpolation.cubic);
  }

  // Quality raised from the Brief's ~90 starting point: since the resize
  // above already does most of the size reduction, there's headroom to
  // spend on quality instead of compounding two lossy passes (ours, then
  // WhatsApp's) at a mediocre setting each — the goal is to hand WhatsApp
  // the best source we can, not the smallest.
  final jpgBytes = img.encodeJpg(oriented, quality: job.quality);
  File(job.outputPath).writeAsBytesSync(jpgBytes);
  return job.outputPath;
}
