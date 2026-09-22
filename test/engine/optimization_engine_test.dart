import 'package:flutter_test/flutter_test.dart';

import 'package:hd_status/engine/optimization_engine.dart';
import 'package:hd_status/models/encoding_plan.dart';
import 'package:hd_status/models/media_info.dart';

MediaInfo _video({
  required int width,
  required int height,
  String mimeType = 'video/mp4',
  int sizeBytes = 5 * 1024 * 1024,
  int durationSeconds = 30,
}) {
  return MediaInfo(
    filePath: '/tmp/in.mp4',
    fileName: 'in.mp4',
    type: MediaType.video,
    mimeType: mimeType,
    width: width,
    height: height,
    duration: Duration(seconds: durationSeconds),
    rotationDegrees: 0,
    sizeBytes: sizeBytes,
  );
}

MediaInfo _image({
  required int width,
  required int height,
  String mimeType = 'image/jpeg',
  int sizeBytes = 500 * 1024,
}) {
  return MediaInfo(
    filePath: '/tmp/in.jpg',
    fileName: 'in.jpg',
    type: MediaType.image,
    mimeType: mimeType,
    width: width,
    height: height,
    duration: null,
    rotationDegrees: 0,
    sizeBytes: sizeBytes,
  );
}

void main() {
  final engine = OptimizationEngine();

  test('video already at or above the quality floor passes through untouched', () {
    final plan = engine.plan(_video(width: 1080, height: 1920));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('4K video already above the floor is never downscaled — passes through', () {
    final plan = engine.plan(_video(width: 3840, height: 2160));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('non-mp4 container above the floor is re-encoded at its NATIVE resolution, not resized', () {
    final plan = engine.plan(_video(width: 1080, height: 1920, mimeType: 'video/quicktime'));
    expect(plan.action, EncodingAction.reencode);
    expect(plan.targetWidth, 1080);
    expect(plan.targetHeight, 1920);
  });

  test('over-size-ceiling file above the floor is re-encoded at its NATIVE resolution, not resized', () {
    final plan = engine.plan(_video(width: 1080, height: 1920, sizeBytes: 30 * 1024 * 1024));
    expect(plan.action, EncodingAction.reencode);
    expect(plan.targetWidth, 1080);
    expect(plan.targetHeight, 1920);
  });

  test('small source video is upscaled up to the quality floor, never left small', () {
    final plan = engine.plan(_video(width: 400, height: 300, mimeType: 'video/quicktime'));
    expect(plan.action, EncodingAction.reencode);
    // 400x300 (landscape) upscaled to cover a 1920x1080 floor: the width is
    // the binding constraint (1920/400 = 4.8x > 1080/300 = 3.6x), so scaling
    // by width leaves height comfortably above the floor too.
    expect(plan.targetWidth, greaterThanOrEqualTo(1920));
    expect(plan.targetHeight, greaterThanOrEqualTo(1080));
  });

  test('image already at or above the quality floor passes through untouched', () {
    final plan = engine.plan(_image(width: 2200, height: 3000));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('large image is never downscaled — passes through', () {
    final plan = engine.plan(_image(width: 4000, height: 3000));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('non-jpeg image above the floor is re-encoded at its NATIVE resolution, not resized', () {
    final plan = engine.plan(_image(width: 2200, height: 3000, mimeType: 'image/png'));
    expect(plan.action, EncodingAction.reencode);
    expect(plan.targetWidth, 2200);
    expect(plan.targetHeight, 3000);
  });

  test('small image is upscaled up to the quality floor, never left small', () {
    final plan = engine.plan(_image(width: 800, height: 600, mimeType: 'image/png'));
    expect(plan.action, EncodingAction.reencode);
    expect(plan.targetWidth, greaterThanOrEqualTo(800));
    final longestEdge = plan.targetWidth > plan.targetHeight ? plan.targetWidth : plan.targetHeight;
    expect(longestEdge, 2200);
  });
}
