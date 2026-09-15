class SegmentPlan {
  const SegmentPlan({required this.index, required this.start, required this.end});

  final int index;
  final Duration start;
  final Duration end;

  Duration get duration => end - start;
}
