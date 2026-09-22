import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// Instruction sheet for the "send to a chat with HD, then forward to
/// Status" workaround — see HD_Status_OnDevice_HD_Chat_Flow.md. WhatsApp
/// doesn't expose an HD toggle on its Status-upload path, only on chat, so
/// the app can't automate the whole thing; this sheet is the "clear
/// instructions" the doc calls out as critical to that gap.
///
/// Returns 'send_to_chat' if the user tapped the primary action,
/// 'use_normal_share' if they chose the secondary one, or null on dismiss.
Future<String?> showHdChatInstructionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final palette = ctx.appPalette;
      final textTheme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Higher quality via HD chat',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'WhatsApp only offers its HD option in chats, not for Status. '
                'This sends your prepared file to a chat first, so you can forward '
                'the higher-quality version to your Status yourself.',
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Step(number: 1, text: "Tap \"Send to a chat\" below — WhatsApp opens with your file attached."),
              _Step(number: 2, text: 'Pick a chat (yourself or anyone).'),
              _Step(number: 3, text: 'Before sending, tap the HD icon.', emphasize: true),
              _Step(number: 4, text: 'Once it sends, long-press the message → Forward → My Status.'),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Send to a chat',
                icon: Icons.chat_outlined,
                onPressed: () => Navigator.pop(ctx, 'send_to_chat'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Use normal Share to Status instead',
                onPressed: () => Navigator.pop(ctx, 'use_normal_share'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text, this.emphasize = false});

  final int number;
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: emphasize
                ? Theme.of(context).colorScheme.primary
                : palette.border,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: emphasize ? Colors.white : palette.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
