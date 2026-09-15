import 'package:flutter/services.dart';

/// Checked before starting an encode/split, not mid-job — per the plan's
/// Phase 9 robustness rule. Uses native StatFs (no free-disk-space API
/// exists in Dart/Flutter core).
class StorageCheckService {
  static const _channel = MethodChannel('com.example.hd_status/storage');

  Future<int> freeBytes() async {
    final bytes = await _channel.invokeMethod<int>('freeBytes');
    return bytes ?? 0;
  }

  /// Rough ceiling: input size × 1.5, per the plan.
  Future<bool> hasEnoughSpaceFor(int inputSizeBytes) async {
    final free = await freeBytes();
    return free > (inputSizeBytes * 1.5);
  }
}
