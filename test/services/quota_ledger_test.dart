import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hd_status/services/quota_ledger.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('starts with the full daily allowance', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    expect(await ledger.remainingToday(QuotaKind.video), 3);
    expect(await ledger.remainingToday(QuotaKind.clip), 5);
  });

  test('reserve then commit consumes one slot permanently', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    expect(await ledger.reserve(QuotaKind.video), isTrue);
    expect(await ledger.remainingToday(QuotaKind.video), 2, reason: 'reservation itself blocks the slot');

    await ledger.commit(QuotaKind.video);
    expect(await ledger.remainingToday(QuotaKind.video), 2);
    expect(await ledger.usedToday(QuotaKind.video), 1);
  });

  test('reserve then release returns the slot (cancel/failure path)', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    await ledger.reserve(QuotaKind.clip, count: 5);
    expect(await ledger.remainingToday(QuotaKind.clip), 0);

    await ledger.release(QuotaKind.clip, count: 5);
    expect(await ledger.remainingToday(QuotaKind.clip), 5);
    expect(await ledger.usedToday(QuotaKind.clip), 0);
  });

  test('reserve fails once the cap is reached', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    expect(await ledger.reserve(QuotaKind.video, count: 3), isTrue);
    expect(await ledger.reserve(QuotaKind.video), isFalse);
  });

  test('partial clip reservation is possible up to the remaining cap', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    // A split producing more clips than remain today should only reserve
    // what's left, not fail outright — the caller decides how many to ask for.
    expect(await ledger.reserve(QuotaKind.clip, count: 5), isTrue);
    expect(await ledger.reserve(QuotaKind.clip, count: 1), isFalse);
  });

  test('resets at local-midnight rollover', () async {
    SharedPreferences.setMockInitialValues({
      'ledger_date': '2000-01-01',
      'videos_used': 3,
      'clips_used': 5,
    });
    final ledger = QuotaLedger(bypassVideoCap: false);
    expect(await ledger.usedToday(QuotaKind.video), 0);
    expect(await ledger.remainingToday(QuotaKind.video), 3);
    expect(await ledger.remainingToday(QuotaKind.clip), 5);
  });

  test('clearStaleReservations frees a reservation left by a killed process', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    await ledger.reserve(QuotaKind.video, count: 2);
    expect(await ledger.remainingToday(QuotaKind.video), 1);

    await ledger.clearStaleReservations();
    expect(await ledger.remainingToday(QuotaKind.video), 3, reason: 'no job can legitimately survive a restart');
    expect(await ledger.usedToday(QuotaKind.video), 0, reason: 'clearing a stale reservation is not the same as using it');
  });

  test('video and clip counters are independent', () async {
    final ledger = QuotaLedger(bypassVideoCap: false);
    await ledger.reserve(QuotaKind.video, count: 3);
    await ledger.commit(QuotaKind.video, count: 3);
    expect(await ledger.remainingToday(QuotaKind.video), 0);
    expect(await ledger.remainingToday(QuotaKind.clip), 5);
  });
}
