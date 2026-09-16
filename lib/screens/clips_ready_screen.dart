import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../channels/media_probe_channel.dart';
import '../models/media_info.dart';
import '../models/share_output.dart';
import '../services/entitlement_service.dart';
import '../services/status_share_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

/// Clips ready. Unlocked clips each get an independent Share/Save/Customize action —
/// one WhatsApp Status share at a time. Locked tiles are a Pro affordance.
class ClipsReadyScreen extends StatelessWidget {
  const ClipsReadyScreen({super.key, required this.clips, required this.lockedCount});

  final List<ShareOutput> clips;
  final int lockedCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clips ready'),
        actions: [
          TextButton.icon(
            onPressed: () => PaywallScreen.show(context, heading: 'Customize clips with Pro'),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Edit / Customize'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lockedCount > 0 ? '${clips.length} ready · $lockedCount need Pro' : '${clips.length} clips ready',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.70,
                  ),
                  itemCount: clips.length + lockedCount,
                  itemBuilder: (context, index) {
                    if (index < clips.length) {
                      return _ClipTile(output: clips[index], index: index);
                    }
                    return _LockedClipTile(index: index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipTile extends StatefulWidget {
  const _ClipTile({required this.output, required this.index});

  final ShareOutput output;
  final int index;

  @override
  State<_ClipTile> createState() => _ClipTileState();
}

class _ClipTileState extends State<_ClipTile> {
  final _shareService = StatusShareService();
  final _entitlement = EntitlementService();
  MediaInfo? _probedInfo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _probeClip();
  }

  Future<void> _probeClip() async {
    try {
      final info = await MediaProbeChannel().probe(widget.output.filePath, widget.output.fileName);
      if (mounted) setState(() => _probedInfo = info);
    } catch (_) {
      // Best-effort preview thumbnail probe
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

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await Gal.putVideo(widget.output.filePath);
      messenger.showSnackBar(const SnackBar(content: Text('Saved to your device')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text("Couldn't save to your device")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCustomize() async {
    final isPro = await _entitlement.isPro();
    if (!mounted) return;

    if (!isPro) {
      await PaywallScreen.show(context, heading: 'Customize clips with Pro');
    } else {
      _showCustomizeSheet(context);
    }
  }

  void _showCustomizeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Clip ${widget.index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.aspect_ratio_rounded),
              title: const Text('Aspect Ratio'),
              subtitle: const Text('9:16 Vertical (WhatsApp Status Default)'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.speed_rounded),
              title: const Text('Playback Speed'),
              subtitle: const Text('1.0x Normal'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.high_quality_rounded),
              title: const Text('Quality Preset'),
              subtitle: const Text('1080p HD Lossless'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreviewModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_probedInfo?.thumbnailPath != null && File(_probedInfo!.thumbnailPath!).existsSync())
                    Image.file(
                      File(_probedInfo!.thumbnailPath!),
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                    )
                  else
                    const Center(child: Icon(Icons.movie_rounded, size: 54, color: Colors.white54)),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Clip ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasThumb = _probedInfo?.thumbnailPath != null && File(_probedInfo!.thumbnailPath!).existsSync();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Thumbnail Preview Area
            Expanded(
              child: GestureDetector(
                onTap: () => _showPreviewModal(context),
                child: Container(
                  width: double.infinity,
                  color: isDark ? const Color(0xFF1A2420) : const Color(0xFFEFEFEF),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasThumb)
                        Image.file(
                          File(_probedInfo!.thumbnailPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 400,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Centered Play Button Badge
                      Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),

                      // Top Left Clip Index Badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Clip ${widget.index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      // Bottom Right Duration Tag
                      if (_probedInfo?.durationLabel != null && _probedInfo!.durationLabel.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _probedInfo!.durationLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // File Details & Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Clip ${widget.index + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        widget.output.sizeLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: palette.secondaryText,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.send_outlined, size: 17),
                        tooltip: 'Share to WhatsApp Status',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _busy ? null : _share,
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_outlined, size: 17),
                        tooltip: 'Save to device',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _busy ? null : _save,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.tune_rounded,
                          size: 17,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        tooltip: 'Edit / Customize (PRO)',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: _busy ? null : _editCustomize,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 36,
          color: context.appPalette.secondaryText.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _LockedClipTile extends StatelessWidget {
  const _LockedClipTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => PaywallScreen.show(context, heading: 'Unlock all clips with Pro'),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(16),
          color: palette.border.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, color: palette.secondaryText, size: 28),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Clip ${index + 1}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
