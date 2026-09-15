import 'package:flutter_test/flutter_test.dart';

import 'package:hd_status/engine/segment_planner.dart';

void main() {
  final planner = SegmentPlanner();

  test('exact multiple of segment length produces clean segments', () {
    final segments = planner.plan(const Duration(seconds: 180), segmentSeconds: 90);
    expect(segments.length, 2);
    expect(segments[0].start, Duration.zero);
    expect(segments[0].end, const Duration(seconds: 90));
    expect(segments[1].start, const Duration(seconds: 90));
    expect(segments[1].end, const Duration(seconds: 180));
  });

  test('non-multiple duration gives a shorter final segment', () {
    final segments = planner.plan(const Duration(seconds: 200), segmentSeconds: 90);
    expect(segments.length, 3);
    expect(segments.last.duration, const Duration(seconds: 20));
  });

  test('every segment except the last is exactly segmentSeconds long', () {
    final segments = planner.plan(const Duration(seconds: 500), segmentSeconds: 90);
    for (final s in segments.sublist(0, segments.length - 1)) {
      expect(s.duration, const Duration(seconds: 90));
    }
  });

  test('segments are contiguous with no gaps or overlaps', () {
    final segments = planner.plan(const Duration(seconds: 365), segmentSeconds: 90);
    for (var i = 1; i < segments.length; i++) {
      expect(segments[i].start, segments[i - 1].end);
    }
  });

  test('zero duration produces no segments', () {
    expect(planner.plan(Duration.zero), isEmpty);
  });
}
