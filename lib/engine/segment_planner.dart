import '../models/segment_plan.dart';
import 'constants.dart';

/// Pure math, no I/O — cuts a source duration into fixed-length segments.
/// Segment boundaries here are what the native encoder trims on (one encode
/// pass per segment, per the plan's "one encode pass" principle) — the
/// planner itself never touches a file.
class SegmentPlanner {
  List<SegmentPlan> plan(Duration totalDuration, {int segmentSeconds = kSegmentSeconds}) {
    if (totalDuration <= Duration.zero) return const [];

    final totalMs = totalDuration.inMilliseconds;
    final segmentMs = segmentSeconds * 1000;
    final count = (totalMs / segmentMs).ceil();

    return List.generate(count, (i) {
      final startMs = i * segmentMs;
      final endMs = ((i + 1) * segmentMs).clamp(0, totalMs);
      return SegmentPlan(index: i, start: Duration(milliseconds: startMs), end: Duration(milliseconds: endMs));
    });
  }
}
