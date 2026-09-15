import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../channels/whatsapp_status_channel.dart';
import '../services/entitlement_service.dart';
import '../services/quota_ledger.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import 'paywall_screen.dart';
import 'selected_media_screen.dart';

/// S02 Home. Free/Pro plan entry, primary "Choose photo or video" action,
/// and the daily usage line. No ads (confirmed: MVP has none) and no
/// History/Settings tabs (out of scope for this MVP) — Home is the app's
/// sole persistent destination.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _picker = ImagePicker();
  final _whatsApp = WhatsAppStatusChannel();
  final _ledger = QuotaLedger();
  final _entitlement = EntitlementService();

  bool _isPro = false;
  int _videosRemaining = 3;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final isPro = await _entitlement.isPro();
    final remaining = await _ledger.remainingToday(QuotaKind.video);
    if (!mounted) return;
    setState(() {
      _isPro = isPro;
      _videosRemaining = remaining;
    });
  }

  Future<void> _chooseMedia() async {
    final picked = await _picker.pickMedia();
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelectedMediaScreen(filePath: picked.path, fileName: picked.name),
      ),
    );
    _refreshStatus();
  }

  Future<void> _goPro() async {
    await PaywallScreen.show(context, heading: 'Prepare more with Pro');
    _refreshStatus();
  }

  String _guessMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  /// TEMPORARY — Phase 2 proof only. Picks raw media and shares it
  /// unmodified straight to WhatsApp Status, bypassing analysis/processing,
  /// to validate the native share path in isolation. Superseded by the
  /// real Selected media → Processing → Result flow above for normal use.
  Future<void> _testRawShare(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final XFile? picked = await _picker.pickMedia();
    if (picked == null) return;

    setState(() => _sharing = true);
    try {
      final installed = await _whatsApp.installedWhatsAppPackages();
      if (installed.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('WhatsApp isn\'t installed. Falling back to Android share sheet.')),
        );
        await _whatsApp.shareGeneric(
          filePath: picked.path,
          fileName: picked.name,
          mimeType: _guessMimeType(picked.path),
        );
        return;
      }

      final target = installed.first;
      final attempted = await _whatsApp.shareToStatus(
        filePath: picked.path,
        fileName: picked.name,
        mimeType: _guessMimeType(picked.path),
        targetPackage: target,
      );

      if (!attempted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Dedicated Status share failed — falling back to Android share sheet.')),
        );
        await _whatsApp.shareGeneric(
          filePath: picked.path,
          fileName: picked.name,
          mimeType: _guessMimeType(picked.path),
        );
      }
    } on PlatformException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: ${e.message}')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'HD Status',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!_isPro)
                    OutlinedButton(
                      onPressed: _goPro,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.border),
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      ),
                      child: const Text('Go Pro'),
                    )
                  else
                    Text('Pro', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              Text(
                'Ready for your next Status?',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xxl),
              PrimaryButton(
                label: 'Choose photo or video',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: _chooseMedia,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _isPro ? 'Pro · Unlimited video optimizations' : '$_videosRemaining of 3 videos left today',
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Images are unlimited',
                style: textTheme.bodySmall?.copyWith(color: palette.secondaryText),
              ),
              const Spacer(flex: 2),
              if (Platform.isAndroid) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SecondaryButton(
                    label: _sharing ? 'Sharing…' : 'Dev: test raw share to Status',
                    onPressed: _sharing ? null : () => _testRawShare(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
