import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../models/share_output.dart';
import '../services/status_share_service.dart';
import '../theme/app_theme.dart';
import 'paywall_screen.dart';

/// Clips ready. Unlocked clips each get an independent Share/Save — one
/// WhatsApp Status share at a time, per the Brief ("each item has its own
/// share action"). Locked tiles are a Pro affordance, not a failed job.
class ClipsReadyScreen extends StatelessWidget {
  const ClipsReadyScreen({super.key, required this.clips, required this.lockedCount});

  final List<ShareOutput> clips;
  final int lockedCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Clips ready')),
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
                    childAspectRatio: 0.85,
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
  bool _busy = false;

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

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: palette.border), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Expanded(child: Center(child: Icon(Icons.play_circle_outline, size: 36, color: palette.secondaryText))),
          Text('Clip ${widget.index + 1}', style: Theme.of(context).textTheme.bodySmall),
          Text(
            widget.output.sizeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.secondaryText),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.send_outlined, size: 18), onPressed: _busy ? null : _share),
              IconButton(icon: const Icon(Icons.download_outlined, size: 18), onPressed: _busy ? null : _save),
            ],
          ),
        ],
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
      borderRadius: BorderRadius.circular(14),
      onTap: () => PaywallScreen.show(context, heading: 'Unlock all clips with Pro'),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(14),
          color: palette.border.withValues(alpha: 0.15),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: palette.secondaryText),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Clip ${index + 1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.secondaryText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
