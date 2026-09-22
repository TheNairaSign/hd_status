import 'package:flutter/material.dart';

import '../channels/whatsapp_status_channel.dart';
import 'whatsapp_package_picker.dart';

/// Resolves which WhatsApp package to target (per UX Guide S07: prompt when
/// both are installed) and falls back to the generic Android share sheet
/// when WhatsApp isn't installed or the dedicated Status path fails.
/// Shared by Result and Clips-ready — both share one media item at a time.
class StatusShareService {
  final _channel = WhatsAppStatusChannel();

  Future<void> share(
    BuildContext context, {
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final installed = await _channel.installedWhatsAppPackages();

    if (installed.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WhatsApp isn't installed. Opening other sharing options.")),
      );
      await _channel.shareGeneric(filePath: filePath, fileName: fileName, mimeType: mimeType);
      return;
    }

    String target;
    if (installed.length == 1) {
      target = installed.first;
    } else {
      if (!context.mounted) return;
      final chosen = await pickWhichWhatsApp(context);
      if (chosen == null) return;
      target = chosen;
    }

    final attempted = await _channel.shareToStatus(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      targetPackage: target,
    );

    if (!attempted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Try another sharing option.')),
      );
      await _channel.shareGeneric(filePath: filePath, fileName: fileName, mimeType: mimeType);
    }
  }
}
