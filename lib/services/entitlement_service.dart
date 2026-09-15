import 'package:shared_preferences/shared_preferences.dart';

/// Pro entitlement state. Phase 7 treats this as a debug-mockable flag set
/// directly by the paywall's "purchase" button; Phase 8 replaces those call
/// sites with real Google Play Billing purchase/restore callbacks — the
/// read side ([isPro]) doesn't change.
class EntitlementService {
  static const _isProKey = 'is_pro';

  Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isProKey) ?? false;
  }

  Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProKey, value);
  }
}
