import 'dart:io';

import 'package:flutter/material.dart';

import '../channels/media_probe_channel.dart';
import '../engine/optimization_engine.dart';
import '../models/encoding_plan.dart';
import '../models/media_info.dart';
import '../models/share_output.dart';
import '../services/quota_ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'daily_limit_sheet.dart';
import 'long_video_screen.dart';
import 'paywall_screen.dart';
import 'processing_screen.dart';
import 'result_screen.dart';

/// S04 Selected media. Analysis happens here, displays a live preview of the
/// selected image or video thumbnail, and routes to Result directly for passthrough,
/// Processing for a re-encode, or replaces itself with LongVideoScreen.
class SelectedMediaScreen extends StatefulWidget {
  const SelectedMediaScreen({super.key, required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;

  @override
  State<SelectedMediaScreen> createState() => _SelectedMediaScreenState();
}

class _SelectedMediaScreenState extends State<SelectedMediaScreen> {
  final _probeChannel = MediaProbeChannel();
  final _ledger = QuotaLedger();

  MediaInfo? _info;
  EncodingPlan? _plan;
  String? _errorMessage;
  bool _navigatingToLongVideo = false;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final info = await _probeChannel.probe(widget.filePath, widget.fileName);

      if (info.exceedsMaxSourceDuration) {
        if (mounted) setState(() => _errorMessage = 'This video is longer than we can prepare yet.');
        return;
      }

      if (!mounted) return;
      final plan = OptimizationEngine().plan(info);
      setState(() {
        _info = info;
        _plan = plan;
      });

      if (info.needsSplitting && !_navigatingToLongVideo) {
        _navigatingToLongVideo = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => LongVideoScreen(mediaInfo: info)),
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "We can't prepare this file.");
    }
  }

  Future<void> _continue() async {
    final info = _info;
    final plan = _plan;
    if (info == null || plan == null) return;

    if (plan.action == EncodingAction.passthrough) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            output: ShareOutput(
              filePath: info.filePath,
              fileName: info.fileName,
              mimeType: info.mimeType ?? (info.type == MediaType.video ? 'video/mp4' : 'image/jpeg'),
              sizeBytes: info.sizeBytes,
              isVideo: info.type == MediaType.video,
              unchanged: true,
            ),
          ),
        ),
      );
      return;
    }

    if (info.type == MediaType.video) {
      final remaining = await _ledger.remainingToday(QuotaKind.video);
      if (remaining <= 0) {
        if (!mounted) return;
        final action = await showDailyLimitSheet(context, DailyLimitKind.video);
        if (!mounted) return;
        if (action == 'go_pro') {
          await PaywallScreen.show(context, heading: 'Unlimited videos with Pro');
        }
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ProcessingScreen(mediaInfo: info, plan: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selected media')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 40, color: palette.secondaryText),
                const SizedBox(height: AppSpacing.lg),
                Text(_errorMessage!, textAlign: TextAlign.center, style: textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
                SecondaryButton(label: 'Choose another', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
        ),
      );
    }

    final info = _info;
    final plan = _plan;

    if (info == null || plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Selected media')),
        body: Center(child: Text('Checking your file…', style: textTheme.bodyLarge)),
      );
    }

    if (info.needsSplitting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ready = plan.action == EncodingAction.passthrough;

    return Scaffold(
      appBar: AppBar(title: const Text('Selected media')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Preview Section (Image or Video Thumbnail)
              _buildMediaPreview(context, info),

              const SizedBox(height: AppSpacing.xl),

              Text(
                ready ? 'This file is ready to share' : plan.reason,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                info.summaryLabel,
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),

              const Spacer(),

              PrimaryButton(label: ready ? 'Continue' : 'Optimize', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, MediaInfo info) {
    final palette = context.appPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = info.type == MediaType.video;

    final fileExists = File(info.filePath).existsSync();
    final hasThumb = info.thumbnailPath != null && File(info.thumbnailPath!).existsSync();

    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2622) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Preview Image / Thumbnail
            if (!isVideo && fileExists)
              Image.file(
                File(info.filePath),
                cacheWidth: 600,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(context, info),
              )
            else if (isVideo && hasThumb)
              Image.file(
                File(info.thumbnailPath!),
                cacheWidth: 600,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(context, info),
              )
            else
              _buildFallbackPlaceholder(context, info),

            // Video Play Overlay Badge
            if (isVideo)
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),

            // Top Type Indicator Badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isVideo ? 'VIDEO' : 'PHOTO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Info Badges (Duration & Dimensions)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (info.dimensionsLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        info.dimensionsLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isVideo && info.durationLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            info.durationLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPlaceholder(BuildContext context, MediaInfo info) {
    final palette = context.appPalette;
    final isVideo = info.type == MediaType.video;

    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isVideo ? Icons.movie_outlined : Icons.image_outlined,
              size: 48,
              color: palette.secondaryText.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              info.fileName,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
