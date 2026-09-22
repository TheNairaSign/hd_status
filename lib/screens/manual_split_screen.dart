import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../channels/media_probe_channel.dart';
import '../engine/constants.dart';
import '../models/media_info.dart';
import '../models/segment_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'splitting_screen.dart';

enum _DragHandle { start, end }

const _filmstripFrameCount = 14;
const _timelineHeight = 64.0;
const _waveformHeight = 26.0;

/// Lets the user pick one custom clip range from the source video instead
/// of the automatic uniform-length split (LongVideoScreen's other option).
/// The selected range is capped at [kSegmentSeconds] — same as every
/// automatic segment, since that's still a single WhatsApp Status clip —
/// and is handed to the exact same [SplittingScreen] the automatic path
/// uses, just with a single caller-defined [SegmentPlan] instead of
/// [SegmentPlanner]'s uniform ones.
class ManualSplitScreen extends StatefulWidget {
  const ManualSplitScreen({super.key, required this.mediaInfo});

  final MediaInfo mediaInfo;

  @override
  State<ManualSplitScreen> createState() => _ManualSplitScreenState();
}

class _ManualSplitScreenState extends State<ManualSplitScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  String? _initError;
  List<String> _frames = const [];

  late Duration _totalDuration;
  late Duration _rangeStart;
  late Duration _rangeEnd;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.mediaInfo.filePath));
    _controller.initialize().then((_) {
      if (!mounted) return;
      final total = widget.mediaInfo.duration ?? _controller.value.duration;
      final maxClip = Duration(seconds: kSegmentSeconds);
      setState(() {
        _totalDuration = total;
        _rangeStart = Duration.zero;
        _rangeEnd = total < maxClip ? total : maxClip;
        _initialized = true;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _initError = "Couldn't load this video for preview");
    });

    // Best-effort — the trim UI still works with a plain track if this
    // comes back empty (unreadable source, extraction failure, etc.).
    MediaProbeChannel()
        .filmstrip(filePath: widget.mediaInfo.filePath, frameCount: _filmstripFrameCount)
        .then((frames) {
      if (mounted) setState(() => _frames = frames);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Duration get _maxClipLength => Duration(seconds: kSegmentSeconds);

  void _onDrag(_DragHandle handle, double fractionDelta) {
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs <= 0) return;
    final deltaMs = (fractionDelta * totalMs).round();

    setState(() {
      if (handle == _DragHandle.start) {
        var newStartMs = (_rangeStart.inMilliseconds + deltaMs).clamp(0, _rangeEnd.inMilliseconds);
        final minStartMs = _rangeEnd.inMilliseconds - _maxClipLength.inMilliseconds;
        if (newStartMs < minStartMs) newStartMs = minStartMs.clamp(0, totalMs);
        _rangeStart = Duration(milliseconds: newStartMs);
        _controller.seekTo(_rangeStart);
      } else {
        var newEndMs = (_rangeEnd.inMilliseconds + deltaMs).clamp(_rangeStart.inMilliseconds, totalMs);
        final maxEndMs = _rangeStart.inMilliseconds + _maxClipLength.inMilliseconds;
        if (newEndMs > maxEndMs) newEndMs = maxEndMs.clamp(0, totalMs);
        _rangeEnd = Duration(milliseconds: newEndMs);
        _controller.seekTo(_rangeEnd);
      }
    });
  }

  void _togglePlayback() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.seekTo(_rangeStart);
      _controller.play();
    }
    setState(() {});
  }

  void _useThisClip() {
    final plan = SegmentPlan(index: 0, start: _rangeStart, end: _rangeEnd);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplittingScreen(
          mediaInfo: widget.mediaInfo,
          segments: [plan],
          allowedCount: 1,
        ),
      ),
    );
  }

  String _label(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a clip')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: _initError != null
              ? Center(child: Text(_initError!, style: textTheme.bodyMedium))
              : !_initialized
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: _togglePlayback,
                              child: AspectRatio(
                                aspectRatio: _controller.value.aspectRatio == 0 ? 9 / 16 : _controller.value.aspectRatio,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      VideoPlayer(_controller),
                                      if (!_controller.value.isPlaying)
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.45),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_label(_rangeStart)} – ${_label(_rangeEnd)}',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_label(_rangeEnd - _rangeStart)} long',
                                style: textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Drag either edge below to choose your clip — up to ${kSegmentSeconds}s, the longest a single Status clip can be.',
                          style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTimeRuler(context),
                        const SizedBox(height: AppSpacing.xs),
                        _buildTimeline(context),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(label: 'Use this clip', onPressed: _useThisClip),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildTimeRuler(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs <= 0) return const SizedBox.shrink();

    // A tick roughly every 10s, but never more than 6 of them on a short clip.
    final tickSeconds = math.max(10, ((_totalDuration.inSeconds / 6).ceil() ~/ 10) * 10);
    final ticks = <Duration>[];
    for (var s = 0; s <= _totalDuration.inSeconds; s += tickSeconds) {
      ticks.add(Duration(seconds: s));
    }

    return SizedBox(
      height: 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: ticks.map((t) {
              final x = (t.inMilliseconds / totalMs) * width;
              final atEnd = x > width - 24;
              return Positioned(
                left: (atEnd ? x - 30 : x - 6).clamp(0, width - 30),
                child: Text(
                  _label(t),
                  style: textTheme.labelSmall?.copyWith(color: palette.secondaryText),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final palette = context.appPalette;
    final primary = Theme.of(context).colorScheme.primary;
    final totalMs = _totalDuration.inMilliseconds;
    const stripHeight = _timelineHeight + _waveformHeight;

    return SizedBox(
      height: stripHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = totalMs == 0 ? 0.0 : (_rangeStart.inMilliseconds / totalMs) * width;
          final endX = totalMs == 0 ? width : (_rangeEnd.inMilliseconds / totalMs) * width;
          final selectionWidth = (endX - startX).clamp(0.0, width);

          Widget handle(_DragHandle which) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => _onDrag(which, details.delta.dx / width),
              child: SizedBox(
                width: 26,
                height: stripHeight,
                child: Center(
                  child: Container(
                    width: 5,
                    height: stripHeight - 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 3)],
                    ),
                  ),
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // Filmstrip + synthetic waveform background.
                Column(
                  children: [
                    SizedBox(
                      height: _timelineHeight,
                      child: _frames.isEmpty
                          ? Container(color: palette.border)
                          : Row(
                              children: _frames
                                  .map((path) => Expanded(
                                        child: Image.file(File(path), fit: BoxFit.cover, height: _timelineHeight),
                                      ))
                                  .toList(),
                            ),
                    ),
                    SizedBox(
                      height: _waveformHeight,
                      child: Container(
                        color: palette.border.withValues(alpha: 0.4),
                        child: _SyntheticWaveform(seed: widget.mediaInfo.fileName.hashCode),
                      ),
                    ),
                  ],
                ),

                // Dim everything outside the selected range.
                Positioned(
                  left: 0,
                  width: startX,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),
                Positioned(
                  left: endX,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(color: Colors.black.withValues(alpha: 0.55)),
                ),

                // Selection border.
                Positioned(
                  left: startX,
                  width: selectionWidth,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: primary, width: 2.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                Positioned(left: (startX - 13).clamp(0, width), child: handle(_DragHandle.start)),
                Positioned(left: (endX - 13).clamp(0, width), child: handle(_DragHandle.end)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Decorative bars, not real audio analysis — a per-file deterministic
/// pattern so the same video always looks the same, purely to match the
/// filmstrip/waveform look of a typical video trimmer.
class _SyntheticWaveform extends StatelessWidget {
  const _SyntheticWaveform({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barCount = (constraints.maxWidth / 4).floor().clamp(1, 200);
        final random = math.Random(seed);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final heightFraction = 0.25 + random.nextDouble() * 0.7;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FractionallySizedBox(
                  heightFactor: heightFraction,
                  child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
