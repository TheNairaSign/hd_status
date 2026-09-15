import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

enum DailyLimitKind { video, clip }

/// S08 Daily limit sheet. No rewarded-ad option (confirmed: MVP has no
/// ads) — just Go Pro or Not now, plus "Choose an image" for the video
/// variant (images are always free, per the Brief).
Future<String?> showDailyLimitSheet(BuildContext context, DailyLimitKind kind) {
  final isVideo = kind == DailyLimitKind.video;
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
                isVideo ? "You've used today's 3 videos" : "You've used today's 5 free clips",
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isVideo
                    ? 'Your free videos reset at 12:00 AM. Images are always unlimited.'
                    : 'Your free clips reset at 12:00 AM.',
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Go Pro', onPressed: () => Navigator.pop(ctx, 'go_pro')),
              const SizedBox(height: AppSpacing.sm),
              if (isVideo)
                SecondaryButton(
                  label: 'Choose an image',
                  onPressed: () => Navigator.pop(ctx, 'choose_image'),
                ),
              SecondaryButton(label: 'Not now', onPressed: () => Navigator.pop(ctx, null)),
            ],
          ),
        ),
      );
    },
  );
}
