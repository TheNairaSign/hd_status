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

  test('already-compliant 1080p H.264 mp4 passes through', () {
    final plan = engine.plan(_video(width: 1080, height: 1920));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('oversized 4K landscape video is re-encoded to fit the landscape box, preserving aspect ratio', () {
    final plan = engine.plan(_video(width: 3840, height: 2160));
    expect(plan.action, EncodingAction.reencode);
    // 3840x2160 is 16:9 — fitting within 1920x1080 lands exactly on the box.
    expect(plan.targetWidth, 1920);
    expect(plan.targetHeight, 1080);
  });

  test('non-mp4 container is re-encoded even if dimensions already fit', () {
    final plan = engine.plan(_video(width: 1080, height: 1920, mimeType: 'video/quicktime'));
    expect(plan.action, EncodingAction.reencode);
  });

  test('over-size-ceiling file is re-encoded even if dimensions fit', () {
    final plan = engine.plan(_video(width: 1080, height: 1920, sizeBytes: 30 * 1024 * 1024));
    expect(plan.action, EncodingAction.reencode);
  });

  test('never upscales a small source video', () {
    final plan = engine.plan(_video(width: 400, height: 300, mimeType: 'video/quicktime'));
    expect(plan.action, EncodingAction.reencode);
    expect(plan.targetWidth, lessThanOrEqualTo(400));
    expect(plan.targetHeight, lessThanOrEqualTo(300));
  });

  test('compliant small jpeg passes through', () {
    final plan = engine.plan(_image(width: 1080, height: 1920));
    expect(plan.action, EncodingAction.passthrough);
  });

  test('oversized image is re-encoded', () {
    final plan = engine.plan(_image(width: 4000, height: 3000));
    expect(plan.action, EncodingAction.reencode);
  });

  test('non-jpeg image is re-encoded even if small', () {
    final plan = engine.plan(_image(width: 800, height: 600, mimeType: 'image/png'));
    expect(plan.action, EncodingAction.reencode);
  });
}
