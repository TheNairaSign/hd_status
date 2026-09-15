import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/onboarding_service.dart';
import 'services/quota_ledger.dart';
import 'services/temp_storage_service.dart';
import 'theme/app_theme.dart';

class HdStatusApp extends StatelessWidget {
  const HdStatusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HD Status',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follow system theme by default; no separate Settings screen exists
      // in this MVP to override it (out of scope per the confirmed plan).
      themeMode: ThemeMode.system,
      home: const _StartupGate(),
    );
  }
}

/// Decides Welcome vs. Home on launch based on the persisted
/// [OnboardingService] flag, per "Welcome ... never returns automatically".
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final _onboarding = OnboardingService();
  bool? _seenWelcome;

  @override
  void initState() {
    super.initState();
    _onboarding.hasSeenWelcome().then((seen) {
      if (mounted) setState(() => _seenWelcome = seen);
    });
    // Fire-and-forget startup robustness (plan Phase 9): a reservation left
    // over from a killed process is always stale on a fresh launch, and
    // share-output files older than 24h are past their sharing grace period.
    QuotaLedger().clearStaleReservations();
    TempStorageService().cleanupOldShareFiles();
  }

  void _goHome() => setState(() => _seenWelcome = true);

  @override
  Widget build(BuildContext context) {
    if (_seenWelcome == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    if (_seenWelcome == false) {
      return WelcomeScreen(onDone: _goHome);
    }
    return const HomeScreen();
  }
}
