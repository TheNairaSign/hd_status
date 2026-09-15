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

/// S04 Selected media. Analysis happens here, no mandatory separate
/// technical-analysis screen, per the UX Guide. Routes to: Result directly
/// for passthrough, Processing for a real re-encode, or replaces itself
/// with Long video when the source is too long for one Status clip.
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
      // About to be replaced by LongVideoScreen (see _analyze) — avoid
      // flashing the normal Optimize UI in the meantime.
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
              Text(
                ready ? 'This file is ready to share' : plan.reason,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(info.summaryLabel, style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText)),
              const Spacer(),
              PrimaryButton(label: ready ? 'Continue' : 'Optimize', onPressed: _continue),
            ],
          ),
        ),
      ),
    );
  }
}
