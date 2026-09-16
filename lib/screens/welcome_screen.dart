import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// S01 Welcome — 2-slide skippable onboarding flow replicating the UX guide design.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onDone});

  /// Called after Welcome is dismissed (skipped or completed) so the caller
  /// can move on to Home.
  final VoidCallback onDone;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _onboarding = OnboardingService();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dismissing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    await _onboarding.markWelcomeSeen();
    widget.onDone();
  }

  void _nextPage() {
    if (_currentPage < 1) {
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar (Skip)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: AppSpacing.sm,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _dismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.secondaryText,
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),

            // PageView containing Onboarding Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildPageOne(context, isDark),
                  _buildPageTwo(context, isDark),
                ],
              ),
            ),

            // Bottom Control Section: Progress Indicators & CTA Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Progress Indicator Bars
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _currentPage == 0 ? 28 : 18,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage == 0
                                ? Theme.of(context).colorScheme.primary
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : palette.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _currentPage == 1 ? 28 : 18,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _currentPage == 1
                                ? Theme.of(context).colorScheme.primary
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : palette.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Main Action Button
                  PrimaryButton(
                    label: 'Choose photo or video',
                    onPressed: _nextPage,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Slide 1: Prepare clearer Status uploads
  Widget _buildPageOne(BuildContext context, bool isDark) {
    final palette = context.appPalette;

    return Column(
      children: [
        // Flexible Hero Visual Area (Photo Stack + Pill Badge)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStackedHeroCards(),
                    const SizedBox(height: 20),
                    _buildBadge(context, isDark, 'Prepared on your phone'),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Text Content
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  'Prepare clearer Status uploads',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Photos and videos are processed on your phone.\nNo account needed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.secondaryText,
                      fontSize: 15,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'WhatsApp may still compress the result.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  // Slide 2: Split long videos automatically
  Widget _buildPageTwo(BuildContext context, bool isDark) {
    final palette = context.appPalette;

    return Column(
      children: [
        // Flexible Hero Visual Area (Video Split Graphic + Pill Badge)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildVideoSplitHeroCard(context, isDark),
                    const SizedBox(height: 20),
                    _buildBadge(context, isDark, 'Automatic 30s status segmenter'),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Text Content
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  'Split long videos automatically',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        height: 1.15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Long videos are seamlessly split into 30-second clips.\nEach segment encodes cleanly.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.secondaryText,
                      fontSize: 15,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Post clips sequentially to your WhatsApp Status in one tap.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.secondaryText.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedHeroCards() {
    return SizedBox(
      width: 270,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Landscape Card (Tilted Left)
          Transform.translate(
            offset: const Offset(-22, 0),
            child: Transform.rotate(
              angle: -0.16, // approx -9 degrees
              child: Container(
                width: 160,
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/welcome_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          // Foreground Portrait Card (Tilted Right)
          Transform.translate(
            offset: const Offset(18, -4),
            child: Transform.rotate(
              angle: 0.10, // approx +5.7 degrees
              child: Container(
                width: 160,
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/welcome_fg.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSplitHeroCard(BuildContext context, bool isDark) {
    final palette = context.appPalette;

    return SizedBox(
      width: 270,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Video Thumbnail Container
          Container(
            width: 240,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/welcome_video.png',
                    fit: BoxFit.cover,
                  ),
                  // Dark gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                  // Centered Play Button Icon
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF006B55),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Split Segment Chips overlay at bottom
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2622) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildClipChip(context, 'Clip 1', '0:30', isPrimary: true),
                  const SizedBox(width: 6),
                  _buildClipChip(context, 'Clip 2', '0:30', isPrimary: false),
                  const SizedBox(width: 6),
                  _buildClipChip(context, 'Clip 3', '0:28', isPrimary: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClipChip(BuildContext context, String label, String duration, {required bool isPrimary}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? primaryColor.withValues(alpha: 0.15)
            : palette.border.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_rounded,
            size: 11,
            color: isPrimary ? primaryColor : palette.secondaryText,
          ),
          const SizedBox(width: 4),
          Text(
            '$label ($duration)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              color: isPrimary ? primaryColor : palette.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, bool isDark, String label) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2623) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : palette.border,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF00B87C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
