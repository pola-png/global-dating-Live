import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  SubscriptionPlan _selectedPlan = SubscriptionPlan.standard;

  final List<Map<String, dynamic>> _plans = [
    {
      'plan': SubscriptionPlan.basic,
      'title': 'Basic',
      'price': '\$2.50',
      'period': 'monthly',
      'desc': 'Perfect for testing the waters',
      'features': [
        'Chat with up to 2 connections',
        'No ads (except group chats)',
      ],
      'color': Colors.blueAccent,
    },
    {
      'plan': SubscriptionPlan.standard,
      'title': 'Standard',
      'price': '\$30.00',
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
      'title': 'Premium',
      'price': '\$99.99',
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
      'title': 'Special VIP',
      'price': '\$199.99',
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

  Future<void> _purchase() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); // Mock transaction delay
    final ok = await SubscriptionService.upgradePlan(_selectedPlan);
    if (mounted) {
      setState(() => _isLoading = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully subscribed to ${_selectedPlan.name.toUpperCase()}!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upgrade failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                      fontSize: 22,
                    ),
                  ),
                  centerTitle: true,
                  leading: widget.showBackButton
                      ? IconButton(
                          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                          onPressed: () => Navigator.pop(context),
                        )
                      : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        const SizedBox(height: 20),
                        // List plans
                        ..._plans.map((p) {
                          final isSelected = _selectedPlan == p['plan'];
                          final planColor = p['color'] as Color;
                          final isCurrentPlan = SubscriptionService.currentPlan == p['plan'];

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
                                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? planColor
                                      : colorScheme.outline.withValues(alpha: 0.2),
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: planColor.withValues(alpha: 0.2),
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSelected
                                                ? LucideIcons.checkCircle2
                                                : LucideIcons.circle,
                                            color: isSelected ? planColor : colorScheme.onSurfaceVariant,
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
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 1),
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
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            p['price'],
                                            style: TextStyle(
                                              color: planColor,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Text(
                                            p['period'],
                                            style: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
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
                                    children: (p['features'] as List<String>)
                                        .map(
                                          (f) => Padding(
                                            padding: const EdgeInsets.only(bottom: 6.0),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  LucideIcons.check,
                                                  color: Colors.greenAccent,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    f,
                                                    style: TextStyle(
                                                      color: colorScheme.onSurface,
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: FilledButton(
                    onPressed: _isLoading ? null : _purchase,
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
