import 'package:shared_preferences/shared_preferences.dart';

import '../engine/constants.dart';

enum QuotaKind { video, clip }

/// Local-midnight-keyed daily ledger for the two free-tier counters.
/// Reserve-on-start / commit-on-success / release-on-cancel-or-fail, per the
/// Product Brief's quota rules — passthrough and re-share never consume.
///
/// Not literally atomic (no cross-process locking) but single-isolate calls
/// are serialized by Dart's event loop, which is enough for a single-app,
/// no-login local ledger; the Brief itself accepts "some reinstall/clock
/// abuse" as out of scope for the MVP's tamper resistance.
class QuotaLedger {
  QuotaLedger({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;

  Future<SharedPreferences> get _prefs async => _prefsOverride ?? await SharedPreferences.getInstance();

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _usedKey(QuotaKind kind) => kind == QuotaKind.video ? 'videos_used' : 'clips_used';
  String _reservedKey(QuotaKind kind) => kind == QuotaKind.video ? 'videos_reserved' : 'clips_reserved';
  int _capFor(QuotaKind kind) => kind == QuotaKind.video ? kFreeVideosPerDay : kFreeClipsPerDay;

  Future<void> _rolloverIfNeeded(SharedPreferences prefs) async {
    final storedDate = prefs.getString('ledger_date');
    if (storedDate != _todayKey) {
      await prefs.setString('ledger_date', _todayKey);
      await prefs.setInt(_usedKey(QuotaKind.video), 0);
      await prefs.setInt(_usedKey(QuotaKind.clip), 0);
      await prefs.setInt(_reservedKey(QuotaKind.video), 0);
      await prefs.setInt(_reservedKey(QuotaKind.clip), 0);
    }
  }

  Future<int> usedToday(QuotaKind kind) async {
    final prefs = await _prefs;
    await _rolloverIfNeeded(prefs);
    return prefs.getInt(_usedKey(kind)) ?? 0;
  }

  Future<int> remainingToday(QuotaKind kind) async {
    final used = await usedToday(kind);
    final prefs = await _prefs;
    final reserved = prefs.getInt(_reservedKey(kind)) ?? 0;
    final remaining = _capFor(kind) - used - reserved;
    return remaining < 0 ? 0 : remaining;
  }

  /// Reserves [count] slots (default 1) so a job in flight can't be
  /// double-spent by a concurrent action. Returns false (reserving nothing)
  /// if fewer than [count] slots remain.
  Future<bool> reserve(QuotaKind kind, {int count = 1}) async {
    final prefs = await _prefs;
    await _rolloverIfNeeded(prefs);
    final remaining = await remainingToday(kind);
    if (remaining < count) return false;
    final reserved = prefs.getInt(_reservedKey(kind)) ?? 0;
    await prefs.setInt(_reservedKey(kind), reserved + count);
    return true;
  }

  /// Converts a reservation into a real usage count — call only after the
  /// job's output has been validated as successful.
  Future<void> commit(QuotaKind kind, {int count = 1}) async {
    final prefs = await _prefs;
    final reserved = prefs.getInt(_reservedKey(kind)) ?? 0;
    final used = prefs.getInt(_usedKey(kind)) ?? 0;
    await prefs.setInt(_reservedKey(kind), (reserved - count).clamp(0, kFreeVideosPerDay + kFreeClipsPerDay));
    await prefs.setInt(_usedKey(kind), used + count);
  }

  /// Releases a reservation without consuming it — call on cancel or failure.
  Future<void> release(QuotaKind kind, {int count = 1}) async {
    final prefs = await _prefs;
    final reserved = prefs.getInt(_reservedKey(kind)) ?? 0;
    await prefs.setInt(_reservedKey(kind), (reserved - count).clamp(0, kFreeVideosPerDay + kFreeClipsPerDay));
  }

  /// Zeroes any leftover reservations from a job that never got to commit or
  /// release — e.g. the process was killed mid-encode. Safe to call on every
  /// app launch: this architecture never resumes a job across a restart, so
  /// a nonzero reservation at startup is always stale, never legitimate.
  Future<void> clearStaleReservations() async {
    final prefs = await _prefs;
    await _rolloverIfNeeded(prefs);
    await prefs.setInt(_reservedKey(QuotaKind.video), 0);
    await prefs.setInt(_reservedKey(QuotaKind.clip), 0);
  }
}
