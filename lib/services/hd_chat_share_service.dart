import 'package:flutter/material.dart';

import '../channels/whatsapp_status_channel.dart';
import 'whatsapp_package_picker.dart';

/// The "send to a chat, tap HD, forward to Status" workaround — see
/// HD_Status_OnDevice_HD_Chat_Flow.md. WhatsApp's HD-quality toggle only
/// exists on the ordinary chat-compose surface, not on the Status
/// deep-link [StatusShareService] uses, so this opens that surface instead
/// and leaves the HD tap + forward-to-Status steps to the user — nothing
/// about them can be driven from here.
class HdChatShareService {
  final _channel = WhatsAppStatusChannel();

  /// Returns false without attempting anything if WhatsApp isn't installed,
  /// so the caller can skip offering this flow at all (per the doc's
  /// "fallback when WhatsApp is missing" checklist item) rather than
  /// opening the chooser only to fail.
  Future<bool> isAvailable() async {
    final installed = await _channel.installedWhatsAppPackages();
    return installed.isNotEmpty;
  }

  Future<void> sendToChat(
    BuildContext context, {
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    final installed = await _channel.installedWhatsAppPackages();

    if (installed.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WhatsApp isn't installed.")),
      );
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

    final attempted = await _channel.shareToChat(
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
      targetPackage: target,
    );

    if (!attempted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open WhatsApp.")),
      );
    }
  }
}
