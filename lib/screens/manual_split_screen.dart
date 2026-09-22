import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../engine/constants.dart';
import '../models/media_info.dart';
import '../models/segment_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'splitting_screen.dart';

enum _DragHandle { start, end }

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
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          '${_label(_rangeStart)} – ${_label(_rangeEnd)}  (${_label(_rangeEnd - _rangeStart)} long)',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Drag either edge below to choose your clip — up to ${kSegmentSeconds}s, the longest a single Status clip can be.',
                          style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildRangeTrack(context),
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(label: 'Use this clip', onPressed: _useThisClip),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildRangeTrack(BuildContext context) {
    final palette = context.appPalette;
    final totalMs = _totalDuration.inMilliseconds;

    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = totalMs == 0 ? 0.0 : (_rangeStart.inMilliseconds / totalMs) * width;
          final endX = totalMs == 0 ? width : (_rangeEnd.inMilliseconds / totalMs) * width;

          Widget handle(_DragHandle which) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => _onDrag(which, details.delta.dx / width),
              child: Container(
                width: 28,
                height: 48,
                alignment: Alignment.center,
                child: Container(
                  width: 6,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }

          return Stack(
            children: [
              Container(
                height: 8,
                margin: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(4)),
              ),
              Positioned(
                left: startX,
                width: (endX - startX).clamp(0, width),
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(left: (startX - 14).clamp(0, width), child: handle(_DragHandle.start)),
              Positioned(left: (endX - 14).clamp(0, width), child: handle(_DragHandle.end)),
            ],
          );
        },
      ),
    );
  }
}
