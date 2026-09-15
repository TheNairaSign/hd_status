import 'package:flutter/material.dart';

import '../engine/segment_planner.dart';
import '../models/media_info.dart';
import '../models/segment_plan.dart';
import '../services/entitlement_service.dart';
import '../services/quota_ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'daily_limit_sheet.dart';
import 'paywall_screen.dart';
import 'splitting_screen.dart';

/// Long video confirmation. Shown automatically when Selected media detects
/// a source longer than one WhatsApp Status clip. Breaks down how many of
/// the resulting clips are free today vs. locked behind Pro, given the
/// `clipsUsedToday` cumulative daily cap — never fails the job outright,
/// per the plan's "mark the remainder locked rather than failing" rule.
class LongVideoScreen extends StatefulWidget {
  const LongVideoScreen({super.key, required this.mediaInfo});

  final MediaInfo mediaInfo;

  @override
  State<LongVideoScreen> createState() => _LongVideoScreenState();
}

class _LongVideoScreenState extends State<LongVideoScreen> {
  final _ledger = QuotaLedger();
  List<SegmentPlan>? _segments;
  int? _remainingClips;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final segments = SegmentPlanner().plan(widget.mediaInfo.duration ?? Duration.zero);
    final remaining = await _ledger.remainingToday(QuotaKind.clip);
    final isPro = await EntitlementService().isPro();
    if (!mounted) return;
    setState(() {
      _segments = segments;
      _remainingClips = remaining;
      _isPro = isPro;
    });

    if (!isPro && remaining == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLimitReached());
    }
  }

  Future<void> _showLimitReached() async {
    final action = await showDailyLimitSheet(context, DailyLimitKind.clip);
    if (!mounted) return;
    if (action == 'go_pro') {
      await PaywallScreen.show(context, heading: 'Unlock unlimited clips with Pro');
      if (mounted) Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _split() {
    final segments = _segments;
    if (segments == null) return;
    final allowed = _isPro ? segments.length : segments.length.clamp(0, _remainingClips ?? 0);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SplittingScreen(
          mediaInfo: widget.mediaInfo,
          segments: segments,
          allowedCount: allowed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    final segments = _segments;
    final remaining = _remainingClips;

    if (segments == null || remaining == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final free = _isPro ? segments.length : segments.length.clamp(0, remaining);
    final locked = segments.length - free;

    return Scaffold(
      appBar: AppBar(title: const Text('Long video')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will become ${segments.length} clips',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Each clip fits WhatsApp Status\'s length limit.',
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_isPro)
                Text('All ${segments.length} will be ready to share.', style: textTheme.bodyMedium)
              else ...[
                Text('$free free today', style: textTheme.bodyMedium),
                if (locked > 0)
                  Text(
                    '$locked will need Pro to unlock',
                    style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
                  ),
              ],
              const Spacer(),
              PrimaryButton(label: 'Split into clips', onPressed: free > 0 || _isPro ? _split : null),
            ],
          ),
        ),
      ),
    );
  }
}
