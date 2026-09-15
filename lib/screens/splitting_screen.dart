import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../channels/video_encoder_channel.dart';
import '../engine/optimization_engine.dart';
import '../models/media_info.dart';
import '../models/segment_plan.dart';
import '../models/share_output.dart';
import '../services/quota_ledger.dart';
import '../services/share_paths.dart';
import '../services/storage_check_service.dart';
import '../theme/app_theme.dart';
import 'clips_ready_screen.dart';

/// One encode pass per segment (trim + resize together), never a separate
/// split-then-reencode step — the native VideoEncoder does the trim via
/// startMs/endMs on the same call that applies the resize effect.
/// Reserves [allowedCount] clip-quota slots up front, commits one per
/// completed clip, releases the rest on cancel.
class SplittingScreen extends StatefulWidget {
  const SplittingScreen({
    super.key,
    required this.mediaInfo,
    required this.segments,
    required this.allowedCount,
  });

  final MediaInfo mediaInfo;
  final List<SegmentPlan> segments;
  final int allowedCount;

  @override
  State<SplittingScreen> createState() => _SplittingScreenState();
}

class _SplittingScreenState extends State<SplittingScreen> {
  final _ledger = QuotaLedger();
  final _videoEncoder = VideoEncoderChannel();
  StreamSubscription<EncodeEvent>? _sub;

  int _currentIndex = 0;
  double _currentProgress = 0;
  bool _cancelled = false;
  final List<ShareOutput> _completed = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    // Rough ceiling: cumulative clip output is roughly the source size, per
    // the plan's "input size × 1.5" heuristic — checked before starting,
    // not mid-split.
    final hasSpace = await StorageCheckService().hasEnoughSpaceFor(widget.mediaInfo.sizeBytes);
    if (!hasSpace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("There isn't enough space to finish. Free up some storage and try again.")),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    if (widget.allowedCount > 0) {
      await _ledger.reserve(QuotaKind.clip, count: widget.allowedCount);
    }
    final plan = OptimizationEngine().plan(widget.mediaInfo);

    for (var i = 0; i < widget.allowedCount; i++) {
      if (_cancelled) break;
      if (mounted) {
        setState(() {
          _currentIndex = i;
          _currentProgress = 0;
        });
      }

      final segment = widget.segments[i];
      final outputPath = await SharePaths.newOutputPath('mp4', prefix: 'clip_${i + 1}');
      final completer = Completer<bool>();

      _sub = _videoEncoder.events.listen((event) {
        switch (event) {
          case EncodeProgress(:final progress):
            if (mounted) setState(() => _currentProgress = progress);
          case EncodeCompleted():
            if (!completer.isCompleted) completer.complete(true);
          case EncodeError():
            if (!completer.isCompleted) completer.complete(false);
        }
      });

      await _videoEncoder.startEncode(
        inputPath: widget.mediaInfo.filePath,
        outputPath: outputPath,
        targetWidth: plan.targetWidth,
        targetHeight: plan.targetHeight,
        targetVideoKbps: plan.targetVideoKbps,
        startMs: segment.start.inMilliseconds,
        endMs: segment.end.inMilliseconds,
      );

      final ok = await completer.future;
      await _sub?.cancel();

      if (ok && File(outputPath).existsSync()) {
        await _ledger.commit(QuotaKind.clip);
        _completed.add(ShareOutput(
          filePath: outputPath,
          fileName: 'clip_${i + 1}.mp4',
          mimeType: 'video/mp4',
          sizeBytes: File(outputPath).lengthSync(),
          isVideo: true,
        ));
      } else {
        await _ledger.release(QuotaKind.clip);
      }
    }

    if (_cancelled) {
      final unspent = widget.allowedCount - _completed.length;
      if (unspent > 0) await _ledger.release(QuotaKind.clip, count: unspent);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ClipsReadyScreen(
          clips: _completed,
          lockedCount: widget.segments.length - _completed.length,
        ),
      ),
    );
  }

  Future<void> _stopRemaining() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop splitting?'),
        content: const Text('Clips already prepared will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Stop')),
        ],
      ),
    );
    if (confirmed == true) {
      _cancelled = true;
      await _sub?.cancel();
      await _videoEncoder.cancelEncode();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _stopRemaining();
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Preparing clip ${_currentIndex + 1} of ${widget.allowedCount}',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                LinearProgressIndicator(value: _currentProgress),
                const SizedBox(height: AppSpacing.xxl),
                TextButton(onPressed: _stopRemaining, child: const Text('Stop')),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Keep HD Status open until this finishes',
                  style: textTheme.bodySmall?.copyWith(color: context.appPalette.secondaryText),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
