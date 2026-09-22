import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../channels/media_probe_channel.dart';
import '../models/media_info.dart';
import '../models/share_output.dart';
import '../services/hd_chat_share_service.dart';
import '../services/quota_ledger.dart';
import '../services/status_share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'hd_chat_instructions_sheet.dart';

/// S06 Result. Displays media preview for the processed output,
/// updated quota allowance, and options to share or save to device.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.output});

  final ShareOutput output;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _shareService = StatusShareService();
  final _hdChatShareService = HdChatShareService();
  final _ledger = QuotaLedger();
  bool _busy = false;
  bool _hdChatAvailable = false;
  int? _videosRemaining;
  MediaInfo? _probedInfo;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (widget.output.isVideo) {
      final remaining = await _ledger.remainingToday(QuotaKind.video);
      if (mounted) setState(() => _videosRemaining = remaining);
    }
    final hdChatAvailable = await _hdChatShareService.isAvailable();
    if (mounted) setState(() => _hdChatAvailable = hdChatAvailable);
    try {
      final info = await MediaProbeChannel().probe(widget.output.filePath, widget.output.fileName);
      if (mounted) setState(() => _probedInfo = info);
    } catch (_) {
      // Best-effort metadata probe for preview thumbnail & labels
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await _shareService.share(
        context,
        filePath: widget.output.filePath,
        fileName: widget.output.fileName,
        mimeType: widget.output.mimeType,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openHdChatFlow() async {
    final choice = await showHdChatInstructionsSheet(context);
    if (choice == null || !mounted) return;

    if (choice == 'use_normal_share') {
      await _share();
      return;
    }

    setState(() => _busy = true);
    try {
      await _hdChatShareService.sendToChat(
        context,
        filePath: widget.output.filePath,
        fileName: widget.output.fileName,
        mimeType: widget.output.mimeType,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (widget.output.isVideo) {
        await Gal.putVideo(widget.output.filePath);
      } else {
        await Gal.putImage(widget.output.filePath);
      }
      messenger.showSnackBar(const SnackBar(content: Text('Saved to your device')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't save to your device")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final output = widget.output;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                output.unchanged ? 'Ready to share · No changes needed' : 'Ready to share',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                output.sizeLabel,
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Media Preview Card
              Expanded(
                child: _buildMediaPreview(context, output),
              ),

              const SizedBox(height: AppSpacing.lg),

              PrimaryButton(
                label: 'Share to WhatsApp',
                icon: Icons.send_outlined,
                onPressed: _busy ? null : _share,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(label: 'Save to device', onPressed: _busy ? null : _save),
              if (_hdChatAvailable) ...[
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Higher quality (via HD chat)',
                  onPressed: _busy ? null : _openHdChatFlow,
                ),
              ],

              if (output.isVideo && _videosRemaining != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$_videosRemaining of 3 videos left today',
                  style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, ShareOutput output) {
    final palette = context.appPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVideo = output.isVideo;
    final info = _probedInfo;

    final fileExists = File(output.filePath).existsSync();
    final hasThumb = info?.thumbnailPath != null && File(info!.thumbnailPath!).existsSync();

    return Container(
      width: double.infinity,
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
                File(output.filePath),
                cacheWidth: 600,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(context, output),
              )
            else if (isVideo && hasThumb)
              Image.file(
                File(info.thumbnailPath!),
                cacheWidth: 600,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallbackPlaceholder(context, output),
              )
            else
              _buildFallbackPlaceholder(context, output),

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
                  if (info != null && info.dimensionsLabel.isNotEmpty)
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
                    )
                  else
                    const SizedBox.shrink(),
                  if (isVideo && info != null && info.durationLabel.isNotEmpty)
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

  Widget _buildFallbackPlaceholder(BuildContext context, ShareOutput output) {
    final palette = context.appPalette;

    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              output.isVideo ? Icons.movie_outlined : Icons.image_outlined,
              size: 48,
              color: palette.secondaryText.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              output.fileName,
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
