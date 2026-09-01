import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/google_play_billing_service.dart';
import '../services/subscription_service.dart';
import 'home_screen.dart';

class PaywallScreen extends StatefulWidget {
  final bool showBackButton;

  const PaywallScreen({super.key, this.showBackButton = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;

  /// True while billing is being initialised (hide prices until ready).
  bool _billingLoading = true;

  /// Whether Google Play billing is available on this device.
  bool _billingAvailable = false;

  SubscriptionPlan _selectedPlan = SubscriptionPlan.standard;

  // Plan metadata — prices are intentionally omitted here; they are fetched
  // from Google Play so the in-app display always matches the payment cart.
  final List<Map<String, dynamic>> _plans = [
    {
      'plan': SubscriptionPlan.basic,
      'productId': GooglePlayBillingService.subBasicProductId,
      'title': 'Basic',
      // Approximate fallback shown ONLY on non-Android platforms where
      // Play billing is unavailable (e.g., web preview).
      'fallbackPrice': 'from \$2.50/mo',
      'period': 'monthly',
      'desc': 'Perfect for testing the waters',
      'features': [
        'Chat with up to 5 connections',
        'Unlock extra chats with coins',
        'No ads (except group chats)',
      ],
      'color': Colors.blueAccent,
    },
    {
      'plan': SubscriptionPlan.standard,
      'productId': GooglePlayBillingService.subStandardProductId,
      'title': 'Standard',
      'fallbackPrice': 'from \$30.00/mo',
      'period': 'monthly',
      'desc': 'Default choice for serious dating',
      'features': [
        'Meet & chat with unlimited people',
        'Private messaging unlocked',
        'Read group chats',
        'No ads (except group chats)',
      ],
      'color': Colors.purpleAccent,
    },
    {
      'plan': SubscriptionPlan.premium,
      'productId': GooglePlayBillingService.subPremiumProductId,
      'title': 'Premium',
      'fallbackPrice': 'from \$99.99/mo',
      'period': 'monthly',
      'desc': 'For highly active daters',
      'features': [
        'Meet VIP matches',
        'Post & interact in Group Chats',
        'High quality private Video Calls',
        'Priority customer support',
      ],
      'color': Colors.amberAccent,
    },
    {
      'plan': SubscriptionPlan.special,
      'productId': GooglePlayBillingService.subSpecialProductId,
      'title': 'Special VIP',
      'fallbackPrice': 'from \$199.99/mo',
      'period': 'monthly',
      'desc': 'Fully concierge matchmaking service',
      'features': [
        'Advanced Matchmaker guidance',
        'Direct connection to Admin/Support',
        'Go live with support agents',
        'Verified Premium Profile Badge',
        'Regular relationship follow-ups',
      ],
      'color': Colors.pinkAccent,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initBilling();
  }

  Future<void> _initBilling() async {
    await GooglePlayBillingService.instance.init();
    if (!mounted) return;
    setState(() {
      _billingLoading = false;
      _billingAvailable = GooglePlayBillingService.instance.isAvailable;
    });
  }

  /// Returns the price string to display for a plan.
  ///
  /// When billing is available (Android with Play Store), returns the
  /// Play Store-sourced localized price so it always matches the payment cart.
  /// When billing is unavailable (non-Android), returns the fallback label.
  String _priceFor(Map<String, dynamic> plan) {
    if (_billingAvailable) {
      final product = GooglePlayBillingService.instance
          .productForId(plan['productId'] as String);
      if (product != null) {
        return '${product.price} / ${plan['period']}';
      }
      // Product not yet loaded from Play; show a neutral placeholder.
      return '—';
    }
    // Billing unavailable (web/desktop preview) — show approximate price.
    return plan['fallbackPrice'] as String;
  }

  Future<void> _purchase() async {
    setState(() => _isLoading = true);

    bool ok = false;

    if (_billingAvailable) {
      // ── Android with Google Play ──────────────────────────────────────────
      // Route through Play billing so the charged price equals what was shown.
      final productId = GooglePlayBillingService.productIdForSubscriptionPlan(
        _selectedPlan,
      );
      if (productId == null) {
        _showError('This plan is not configured for purchase.');
        setState(() => _isLoading = false);
        return;
      }

      final product =
          GooglePlayBillingService.instance.productForId(productId);
      if (product == null) {
        _showError(
          'Plan pricing could not be loaded from Google Play. '
          'Please check your internet connection and try again.',
        );
        setState(() => _isLoading = false);
        return;
      }

      ok = await GooglePlayBillingService.instance.buySubscription(productId);
    } else {
      // ── Non-Android / web fallback ────────────────────────────────────────
      // Billing is unavailable on this platform; record locally only.
      await Future.delayed(const Duration(seconds: 1));
      ok = await SubscriptionService.upgradePlan(_selectedPlan);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully subscribed to ${_selectedPlan.name.toUpperCase()}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        _showError('Upgrade failed. Please try again.');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode
                    ? [
                        const Color(0xFF0F0C20),
                        const Color(0xFF15102A),
                        const Color(0xFF1E153D),
                      ]
                    : [
                        colorScheme.surface,
                        colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        colorScheme.surfaceContainerHighest,
                      ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    'Choose Your Access Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      fontSize: 20,
                    ),
                  ),
                  centerTitle: true,
                  leading: widget.showBackButton
                      ? IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: colorScheme.onSurface, size: 26),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back',
                        )
                      : null,
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colorScheme.onSurface,
                          size: 26,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/home');
                          }
                        },
                        tooltip: 'Dismiss / Continue Free',
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Unlock Dating Connect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'A paid subscription is required to unlock full unlimited features. You can dismiss this screen at any time to explore limited free access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // While billing is initialising, show a loading
                        // indicator — never show prices until we have the
                        // Play Store data so prices are never mismatched.
                        if (_billingLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          // Plan cards
                          ..._plans.map((p) {
                            final isSelected = _selectedPlan == p['plan'];
                            final planColor = p['color'] as Color;
                            final isCurrentPlan =
                                SubscriptionService.currentPlan == p['plan'];
                            final priceLabel = _priceFor(p);

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedPlan = p['plan'];
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? planColor.withValues(alpha: 0.12)
                                      : colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? planColor
                                        : colorScheme.outline
                                            .withValues(alpha: 0.2),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color:
                                                planColor.withValues(alpha: 0.2),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Plan name + selection indicator
                                        Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? LucideIcons.checkCircle2
                                                  : LucideIcons.circle,
                                              color: isSelected
                                                  ? planColor
                                                  : colorScheme
                                                      .onSurfaceVariant,
                                              size: 24,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              p['title'],
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (isCurrentPlan) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.green
                                                        .withValues(alpha: 0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Current',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),

                                        // Price — always from Play Store on Android
                                        Text(
                                          priceLabel,
                                          style: TextStyle(
                                            color: planColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p['desc'],
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const Divider(height: 24),
                                    Column(
                                      children:
                                          (p['features'] as List<String>)
                                              .map(
                                                (f) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6.0),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        LucideIcons.check,
                                                        color:
                                                            Colors.greenAccent,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          f,
                                                          style: TextStyle(
                                                            color: colorScheme
                                                                .onSurface,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),

                          // Disclaimer shown when billing is unavailable
                          // (non-Android) so users know prices are approximate.
                          if (!_billingAvailable)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 12, top: 4),
                              child: Text(
                                'Prices shown are approximate. '
                                'The exact amount will be confirmed in the Google Play payment screen.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Subscribe button — disabled while billing is loading
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 20.0),
                  child: FilledButton(
                    onPressed:
                        (_isLoading || _billingLoading) ? null : _purchase,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Text(
                            'Subscribe',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
