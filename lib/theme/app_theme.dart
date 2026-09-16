import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep teal / soft mint / warm-neutral palette, from the UX Guide's
/// color scheme table. Values are fixed per theme, not derived, so they
/// stay traceable back to that table.
class AppColors {
  const AppColors._();

  static const light = _Palette(
    card: Color(0xFFFAFAF8),
    background: Color(0xFFFFFFFF),
    primary: Color(0xFF006B55),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFF17211D),
    secondaryText: Color(0xFF59665F),
    border: Color(0xFFDCE5DF),
    error: Color(0xFFB42318),
  );

  static const dark = _Palette(
    background: Color(0xff141414),
    card: Color(0xff212121),
    // primary: Color(0xFF69D5AF),
    primary: Color(0xFF3BB273),
    onPrimary: Color(0xFF121816),
    text: Color(0xFFF3F7F5),
    secondaryText: Color(0xFFADBDB4),
    border: Color(0xFF34463C),
    error: Color(0xFFFFB4AB),
  );
}

class _Palette {
  const _Palette({
    required this.background,
    required this.card,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.error,
  });

  final Color background;
  final Color card;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color secondaryText;
  final Color border;
  final Color error;
}

/// 4/8-point spacing system per the UX Guide's typography and spacing rules.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const screenPadding = 20.0; // 16-24dp side padding
}

/// Minimum touch target size per the UX Guide ("at least 48 dp touch areas").
const double kMinTouchTarget = 48.0;

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(_Palette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.primary,
      onSecondary: p.onPrimary,
      error: p.error,
      onError: p.onPrimary,
      surface: p.card,
      onSurface: p.text,
    );

    final textTheme = GoogleFonts.dmSansTextTheme().apply(
      bodyColor: p.text,
      displayColor: p.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      // Screen titles ~24-28sp, this maps roughly onto Material's headline roles.
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size.fromHeight(kMinTouchTarget + 8),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: BorderSide(color: p.border),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
        ),
      ),
      dividerColor: p.border,
      extensions: [AppPaletteExtension(secondaryText: p.secondaryText, border: p.border)],
    );
  }
}

/// Carries palette roles that don't have a direct [ColorScheme] slot
/// (secondary/helper text at 14sp per the UX Guide, and borders).
class AppPaletteExtension extends ThemeExtension<AppPaletteExtension> {
  const AppPaletteExtension({required this.secondaryText, required this.border});

  final Color secondaryText;
  final Color border;

  @override
  AppPaletteExtension copyWith({Color? secondaryText, Color? border}) {
    return AppPaletteExtension(
      secondaryText: secondaryText ?? this.secondaryText,
      border: border ?? this.border,
    );
  }

  @override
  AppPaletteExtension lerp(ThemeExtension<AppPaletteExtension>? other, double t) {
    if (other is! AppPaletteExtension) return this;
    return AppPaletteExtension(
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPaletteExtension get appPalette =>
      Theme.of(this).extension<AppPaletteExtension>()!;
}
