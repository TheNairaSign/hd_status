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

/// S02 Home screen matching the UX guide design.
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

  /// TEMPORARY — Phase 2 proof only.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // Top Header Row (Logo + App Name + Go Pro Button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF006B55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'HD Status',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  if (!_isPro)
                    OutlinedButton(
                      onPressed: _goPro,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: palette.border),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Go Pro'),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Pro',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // Title Headline
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  'Ready for your next Status?',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 28,
                    height: 1.2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 1. Main Action Button ("Choose photo or video")
              PrimaryButton(
                label: 'Choose photo or video',
                onPressed: _chooseMedia,
              ),

              const SizedBox(height: 12),

              // 2. "Select multiple" PRO Button
              InkWell(
                onTap: () {}, // Empty onPressed as requested
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    // color: isDark ? const Color(0xFF1C2622) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Select multiple',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B382B)
                              : const Color(0xFFE2F3EC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF69D5AF)
                                : const Color(0xFF006B55),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 3. "Split a long video" Card
              InkWell(
                onTap: () {}, // Empty onPressed as requested
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    // color: isDark ? const Color(0xFF1C2622) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Split a long video',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Clips longer than 1:30 become consecutive Status clips',
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.secondaryText,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: palette.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 4. Daily Quota Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  // color: isDark ? const Color(0xFF1C2622) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            3,
                            (index) => Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: index < _videosRemaining
                                    ? const Color(0xFF00B87C)
                                    : palette.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPro
                              ? 'Pro · Unlimited video optimizations'
                              : '$_videosRemaining of 3 videos left today',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Images are unlimited.',
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

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
