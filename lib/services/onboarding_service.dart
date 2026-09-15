import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether Welcome has been shown. Welcome is skippable and, per the
/// UX Guide, "never returns automatically" once seen or skipped.
class OnboardingService {
  static const _welcomeSeenKey = 'welcome_seen';

  Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_welcomeSeenKey) ?? false;
  }

  Future<void> markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
  }
}
