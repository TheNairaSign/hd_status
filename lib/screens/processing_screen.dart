import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/constants.dart';
import '../channels/video_encoder_channel.dart';
import '../models/encoding_plan.dart';
import '../models/media_info.dart';
import '../models/share_output.dart';
import '../processors/image_processor.dart';
import '../services/quota_ledger.dart';
import '../services/share_paths.dart';
import '../services/storage_check_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'result_screen.dart';

/// S05 Processing. Only reached for a real re-encode.
/// Displays a modern, rich optimization progress screen with media thumbnail preview,
/// real-time progress indicators, stage checklist, and quota safeguards.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.mediaInfo, required this.plan});

  final MediaInfo mediaInfo;
  final EncodingPlan plan;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  final _ledger = QuotaLedger();
  final _videoEncoder = VideoEncoderChannel();
  StreamSubscription<EncodeEvent>? _sub;
  late AnimationController _pulseController;
  Timer? _imageProgressTicker;

  double _progress = 0;
  String _stage = 'Preparing';
  bool _reserved = false;
  bool _failed = false;
  bool _cancelled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _imageProgressTicker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.mediaInfo.type == MediaType.image) {
      await _runImage();
    } else {
      await _runVideo();
    }
  }

  Future<void> _runImage() async {
    setState(() {
      _stage = 'Optimizing photo';
      _progress = 0.05;
    });

    // ImageProcessor.optimize() has no real progress stream (it's a single
    // background-isolate call, not a step-by-step native encode) — this
    // eases the displayed value toward 90% so the UI visibly moves instead
    // of sitting at one fixed number, then jumps to 100% on completion.
    _imageProgressTicker = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (!mounted) return;
      setState(() => _progress += (0.9 - _progress) * 0.15);
    });

    try {
      final outputPath = await ImageProcessor().optimize(widget.mediaInfo.filePath);
      _imageProgressTicker?.cancel();
      if (_cancelled) return;
      if (mounted) setState(() => _progress = 1.0);
      _goToResult(outputPath, File(outputPath).lengthSync());
    } catch (e) {
      _imageProgressTicker?.cancel();
      if (_cancelled) return;
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
                ? 'Analyzing video streams'
                : progress < 0.85
                    ? 'Encoding HD Status output'
                    : 'Finalizing optimization';
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
      audioKbps: widget.plan.targetVideoKbps > 0 ? VideoEncodeProfile.audioKbps : 0,
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
        title: const Text('Cancel optimization?'),
        content: const Text('Cancelling will stop processing. Your video allowance will be preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep optimizing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel')),
        ],
      ),
    );
    if (confirmed == true) {
      _cancelled = true;
      _imageProgressTicker?.cancel();
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
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmCancel()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Optimizing Status'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (await _confirmCancel()) {
                  navigator.pop();
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: _failed ? _buildError(context, textTheme, palette) : _buildProgress(context, textTheme, palette),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, TextTheme textTheme, AppPaletteExtension palette) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = widget.mediaInfo.type == MediaType.video;
    final percentInt = (_progress * 100).clamp(0, 100).toInt();

    return Column(
      children: [
        const SizedBox(height: 12),

        // Hero Preview Card with Animated Pulsing Border & Progress Badge
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowOpacity = 0.2 + (_pulseController.value * 0.3);
              return Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: glowOpacity),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Media Thumbnail
                  _buildPreviewImage(context),

                  // Translucent Processing Overlay
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),

                  // Center Circular Progress Ring & Percentage
                  Center(
                    child: SizedBox(
                      width: 84,
                      height: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 84,
                            height: 84,
                            child: CircularProgressIndicator(
                              value: _progress > 0 ? _progress : null,
                              strokeWidth: 5,
                              color: Theme.of(context).colorScheme.primary,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$percentInt%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Media Type Tag
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isVideo ? 'HD VIDEO' : 'HD PHOTO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Stage Title & Subtitle
        Text(
          _stage,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Applying optimal WhatsApp encoding parameters',
          style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Thick Custom Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 8,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : palette.border,
          ),
        ),

        const SizedBox(height: 24),

        // Encoding Preset Technical Detail Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2622) : const Color(0xFFF5F7F6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricTile(
                context,
                label: 'Resolution',
                value: '${widget.plan.targetWidth}×${widget.plan.targetHeight}',
              ),
              Container(width: 1, height: 28, color: palette.border),
              _buildMetricTile(
                context,
                label: 'Format',
                value: isVideo ? 'H.264 MP4' : 'JPEG HD',
              ),
              Container(width: 1, height: 28, color: palette.border),
              _buildMetricTile(
                context,
                label: 'Target',
                value: 'WhatsApp HD',
              ),
            ],
          ),
        ),

        const Spacer(),

        // Keep App Open Safety Notice
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : palette.border.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_clock_rounded,
                size: 16,
                color: palette.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                'Keep HD Status open while processing',
                style: textTheme.bodySmall?.copyWith(
                  color: palette.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Cancel Action Button
        SecondaryButton(
          label: 'Cancel Optimization',
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (await _confirmCancel()) {
              navigator.pop();
            }
          },
        ),
      ],
    );
  }

  Widget _buildPreviewImage(BuildContext context) {
    final info = widget.mediaInfo;
    final fileExists = File(info.filePath).existsSync();
    final hasThumb = info.thumbnailPath != null && File(info.thumbnailPath!).existsSync();

    if (info.type == MediaType.image && fileExists) {
      return Image.file(File(info.filePath), cacheWidth: 600, fit: BoxFit.cover);
    } else if (info.type == MediaType.video && hasThumb) {
      return Image.file(File(info.thumbnailPath!), cacheWidth: 600, fit: BoxFit.cover);
    }

    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          info.type == MediaType.video ? Icons.movie_rounded : Icons.photo_rounded,
          size: 54,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, {required String label, required String value}) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.appPalette;

    return Column(
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: palette.secondaryText,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, TextTheme textTheme, AppPaletteExtension palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error, size: 54),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _errorMessage ?? 'Something went wrong',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: 'Choose another file',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
