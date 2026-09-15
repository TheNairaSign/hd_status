import 'package:flutter/material.dart';

import '../services/entitlement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

enum PaywallPlan { yearly, monthly, lifetime }

/// S09 Paywall. Prices and copy are the Product Brief's exact confirmed
/// values — do not adjust without checking the Brief. Purchase is MOCKED
/// here (flips a local entitlement flag) pending Phase 8's real Google Play
/// Billing wiring; every call site should keep working unchanged once that
/// lands, since only `_purchase`/`_restore` bodies change.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.heading = 'Prepare more with Pro'});

  final String heading;

  static Future<bool?> show(BuildContext context, {String heading = 'Prepare more with Pro'}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaywallScreen(heading: heading), fullscreenDialog: true),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  PaywallPlan _selected = PaywallPlan.yearly;
  bool _purchasing = false;

  Future<void> _purchase() async {
    setState(() => _purchasing = true);
    // Phase 8 TODO: replace with a real Google Play Billing purchase flow
    // (product IDs per plan, pending/cancelled/failed states, store-price
    // fetch) — see plan Phase 8. This mock exists so every downstream
    // screen (paywall entry points, entitlement gating) can be built and
    // tested now without waiting on Play Console setup.
    await Future.delayed(const Duration(milliseconds: 400));
    await EntitlementService().setPro(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro is ready')));
    Navigator.of(context).pop(true);
  }

  Future<void> _restore() async {
    // Phase 8 TODO: real restore via Google Play Billing.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No Pro purchase found for this Google Play account.')),
    );
  }

  String _planLabel(PaywallPlan p) => switch (p) {
        PaywallPlan.yearly => 'yearly · ₦9,900/year',
        PaywallPlan.monthly => 'monthly · ₦1,500/month',
        PaywallPlan.lifetime => 'lifetime · ₦19,900',
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.heading, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unlimited videos · Unlimited clips · No daily limits',
                style: textTheme.bodyMedium?.copyWith(color: palette.secondaryText),
              ),
              const SizedBox(height: AppSpacing.xl),
              _PlanTile(
                label: 'Yearly',
                price: '₦9,900/year',
                sub: '₦825/month equivalent, billed yearly · save 45%',
                selected: _selected == PaywallPlan.yearly,
                onTap: () => setState(() => _selected = PaywallPlan.yearly),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PlanTile(
                label: 'Monthly',
                price: '₦1,500/month',
                sub: 'Renews monthly',
                selected: _selected == PaywallPlan.monthly,
                onTap: () => setState(() => _selected = PaywallPlan.monthly),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PlanTile(
                label: 'Lifetime',
                price: '₦19,900 once',
                sub: 'One-time payment · no renewal',
                selected: _selected == PaywallPlan.lifetime,
                onTap: () => setState(() => _selected = PaywallPlan.lifetime),
              ),
              const Spacer(),
              PrimaryButton(
                label: _purchasing ? 'Processing…' : 'Continue with ${_planLabel(_selected)}',
                onPressed: _purchasing ? null : _purchase,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(onPressed: _purchasing ? null : _restore, child: const Text('Restore purchases')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.label,
    required this.price,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final primary = Theme.of(context).colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : palette.border, width: selected ? 2 : 1),
          color: selected ? primary.withValues(alpha: 0.06) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(sub, style: textTheme.bodySmall?.copyWith(color: palette.secondaryText)),
                ],
              ),
            ),
            Text(price, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
