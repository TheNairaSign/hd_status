import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../channels/video_encoder_channel.dart';
import '../models/encoding_plan.dart';
import '../models/media_info.dart';
import '../models/share_output.dart';
import '../processors/image_processor.dart';
import '../services/quota_ledger.dart';
import '../services/share_paths.dart';
import '../services/storage_check_service.dart';
import '../theme/app_theme.dart';
import 'result_screen.dart';

/// S05 Processing. Only ever reached for a real re-encode — passthrough
/// media skips straight from Selected media to Result. Reserves a
/// `videosUsedToday` slot before starting (video only; images never consume
/// it), commits on success, releases on cancel or failure.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.mediaInfo, required this.plan});

  final MediaInfo mediaInfo;
  final EncodingPlan plan;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  final _ledger = QuotaLedger();
  final _videoEncoder = VideoEncoderChannel();
  StreamSubscription<EncodeEvent>? _sub;

  double _progress = 0;
  String _stage = 'Preparing';
  bool _reserved = false;
  bool _failed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (widget.mediaInfo.type == MediaType.image) {
      await _runImage();
    } else {
      await _runVideo();
    }
  }

  Future<void> _runImage() async {
    setState(() => _stage = 'Optimizing');
    try {
      final outputPath = await ImageProcessor().optimize(widget.mediaInfo.filePath);
      _goToResult(outputPath, File(outputPath).lengthSync());
    } catch (e) {
      _fail("We couldn't prepare this photo.");
    }
  }

  Future<void> _runVideo() async {
    final hasSpace = await StorageCheckService().hasEnoughSpaceFor(widget.mediaInfo.sizeBytes);
    if (!hasSpace) {
      _fail('There isn\'t enough space to finish. Free up some storage and try again.');
      return;
    }

    final reserved = await _ledger.reserve(QuotaKind.video);
    if (!reserved) {
      // Selected media should have gated entry on remaining allowance —
      // this is a defensive fallback, not the primary limit-sheet path.
      _fail("You've used today's videos. Go back and choose an image, or go Pro.");
      return;
    }
    _reserved = true;

    setState(() => _stage = 'Preparing your video');
    final outputPath = await SharePaths.newOutputPath('mp4');

    _sub = _videoEncoder.events.listen((event) {
      switch (event) {
        case EncodeProgress(:final progress):
          setState(() {
            _progress = progress;
            _stage = progress < 0.3
                ? 'Preparing your video'
                : progress < 0.85
                    ? 'Optimizing'
                    : 'Checking the result';
          });
        case EncodeCompleted(:final outputPath):
          _onVideoCompleted(outputPath);
        case EncodeError(:final message):
          _onVideoFailed(message);
      }
    });

    await _videoEncoder.startEncode(
      inputPath: widget.mediaInfo.filePath,
      outputPath: outputPath,
      targetWidth: widget.plan.targetWidth,
      targetHeight: widget.plan.targetHeight,
      targetVideoKbps: widget.plan.targetVideoKbps,
    );
  }

  Future<void> _onVideoCompleted(String outputPath) async {
    await _sub?.cancel();
    await _ledger.commit(QuotaKind.video);
    _reserved = false;
    final size = File(outputPath).existsSync() ? File(outputPath).lengthSync() : 0;
    _goToResult(outputPath, size);
  }

  Future<void> _onVideoFailed(String message) async {
    await _sub?.cancel();
    if (_reserved) {
      await _ledger.release(QuotaKind.video);
      _reserved = false;
    }
    _fail("We couldn't prepare this video.");
  }

  void _goToResult(String outputPath, int sizeBytes) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          output: ShareOutput(
            filePath: outputPath,
            fileName: outputPath.split('/').last,
            mimeType: widget.mediaInfo.type == MediaType.image ? 'image/jpeg' : 'video/mp4',
            sizeBytes: sizeBytes,
            isVideo: widget.mediaInfo.type == MediaType.video,
          ),
        ),
      ),
    );
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      _errorMessage = message;
    });
  }

  Future<bool> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this optimization?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep optimizing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel optimization')),
        ],
      ),
    );
    if (confirmed == true) {
      await _sub?.cancel();
      await _videoEncoder.cancelEncode();
      if (_reserved) {
        await _ledger.release(QuotaKind.video);
        _reserved = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cancelled. Your video allowance hasn't changed.")),
        );
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmCancel() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: _failed ? _buildError(textTheme, palette) : _buildProgress(textTheme, palette),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(TextTheme textTheme, AppPaletteExtension palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_stage, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xl),
        LinearProgressIndicator(value: widget.mediaInfo.type == MediaType.video ? _progress : null),
        const SizedBox(height: AppSpacing.xxl),
        TextButton(
          onPressed: () async {
            if (await _confirmCancel() && mounted) Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        if (widget.mediaInfo.type == MediaType.video) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            // No foreground service backs this yet (plan Phase 9's accepted
            // MVP trade-off) — backgrounding can let the OS kill the job.
            'Keep HD Status open until this finishes',
            style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
          ),
        ],
      ],
    );
  }

  Widget _buildError(TextTheme textTheme, AppPaletteExtension palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: palette.border, size: 40),
        const SizedBox(height: AppSpacing.lg),
        Text(_errorMessage ?? 'Something went wrong', textAlign: TextAlign.center, style: textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Choose another')),
      ],
    );
  }
}
