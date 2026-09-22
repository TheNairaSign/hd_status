import 'package:flutter/material.dart';

import '../channels/whatsapp_status_channel.dart';

/// Shared by [StatusShareService] and [HdChatShareService] — both need to
/// ask which WhatsApp to target when both the consumer and Business apps
/// are installed.
Future<String?> pickWhichWhatsApp(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('WhatsApp'),
            onTap: () => Navigator.pop(ctx, WhatsAppPackage.consumer),
          ),
          ListTile(
            title: const Text('WhatsApp Business'),
            onTap: () => Navigator.pop(ctx, WhatsAppPackage.business),
          ),
        ],
      ),
    ),
  );
}
