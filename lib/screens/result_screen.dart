import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../models/share_output.dart';
import '../services/quota_ledger.dart';
import '../services/status_share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// S06 Result. A successful transform has already consumed its slot before
/// this screen is ever shown (Processing does that) — this screen only
/// displays the updated allowance, never decrements it itself. Saving or
/// re-sharing from here never re-encodes and never touches the ledger.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.output});

  final ShareOutput output;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _shareService = StatusShareService();
  final _ledger = QuotaLedger();
  bool _busy = false;
  int? _videosRemaining;

  @override
  void initState() {
    super.initState();
    if (widget.output.isVideo) {
      _ledger.remainingToday(QuotaKind.video).then((v) {
        if (mounted) setState(() => _videosRemaining = v);
      });
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
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: palette.border.withValues(alpha: 0.3),
                    width: double.infinity,
                    child: output.isVideo
                        ? Center(
                            child: Icon(Icons.play_circle_outline, size: 64, color: palette.secondaryText),
                          )
                        : Image.file(File(output.filePath), fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(output.sizeLabel, style: textTheme.bodySmall?.copyWith(color: palette.secondaryText)),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Share to WhatsApp',
                icon: Icons.send_outlined,
                onPressed: _busy ? null : _share,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(label: 'Save to device', onPressed: _busy ? null : _save),
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
}
