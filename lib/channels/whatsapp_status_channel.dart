import 'package:flutter/services.dart';

/// Package names for the two WhatsApp apps, mirrored from the Kotlin side's
/// `WhatsAppPackages` object.
class WhatsAppPackage {
  const WhatsAppPackage._();
  static const consumer = 'com.whatsapp';
  static const business = 'com.whatsapp.w4b';
}

/// Bridges to `WhatsAppStatusSharer.kt` via `MainActivity.kt`'s MethodChannel.
/// See android/app/.../share/WhatsAppStatusSharer.kt for the native mechanics
/// (adapted from Meta's fbsamples/whatsapp_status_api_android reference).
class WhatsAppStatusChannel {
  static const _channel = MethodChannel('com.example.hd_status/whatsapp_status');

  /// Which of [WhatsAppPackage.consumer]/[WhatsAppPackage.business] are
  /// installed on this device. Empty means WhatsApp isn't installed at all.
  Future<List<String>> installedWhatsAppPackages() async {
    final result = await _channel.invokeMethod<List<Object?>>('installedWhatsAppPackages');
    return (result ?? const []).cast<String>();
  }

  /// Attempts the dedicated Status share path. Returns false if the launch
  /// itself failed (e.g. ActivityNotFoundException) — the caller should then
  /// fall back to [shareGeneric], per the Product Brief's fallback rule.
  Future<bool> shareToStatus({
    required String filePath,
    required String fileName,
    required String mimeType,
    required String targetPackage,
  }) async {
    final attempted = await _channel.invokeMethod<bool>('shareToStatus', {
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'targetPackage': targetPackage,
    });
    return attempted ?? false;
  }

  /// Generic Android share sheet — always available fallback.
  Future<void> shareGeneric({
    required String filePath,
    required String fileName,
    required String mimeType,
  }) {
    return _channel.invokeMethod('shareGeneric', {
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }
}
