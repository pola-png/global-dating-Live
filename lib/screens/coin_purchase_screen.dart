import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components/responsive_page.dart';
import '../services/google_play_billing_service.dart';
import '../services/wallet_service.dart';
import '../services/admob_service.dart';
import '../services/supabase_service.dart';

class CoinPurchaseScreen extends StatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  State<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends State<CoinPurchaseScreen> {
  final Set<int> _processingCoins = {};
  int _balance = 0;
  bool _billingReady = false;
  bool _billingAvailable = false;



  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadBilling();
  }

  Future<void> _loadBalance() async {
    final balance = await WalletService.getBalance();
    if (mounted) setState(() => _balance = balance);
  }

  Future<void> _loadBilling() async {
    await GooglePlayBillingService.instance.init();
    if (!mounted) return;
    setState(() {
      _billingReady = true;
      _billingAvailable = GooglePlayBillingService.instance.isAvailable;
    });
  }

  String? _productIdForCoins(int coins) {
    switch (coins) {
      case 10:
        return GooglePlayBillingService.coins10ProductId;
      case 30:
        return GooglePlayBillingService.coins30ProductId;
      case 60:
        return GooglePlayBillingService.coins60ProductId;
      default:
        return null;
    }
  }

  Future<void> _buyCoins(int coins) async {
    final service = GooglePlayBillingService.instance;
    if (!service.isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Play billing is only available on Android.'),
          ),
        );
      }
      return;
    }

    final productId = _productIdForCoins(coins);
    if (productId == null || service.productForId(productId) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That coin pack is not configured in Google Play Console yet.'),
          ),
        );
      }
      return;
    }

    setState(() => _processingCoins.add(coins));
    final success = await service.buyCoins(coins);
    if (success) {
      await _loadBalance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$coins coins purchased successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _processingCoins.remove(coins));
    }
  }

  Future<void> _watchAdsForCoins(int coins, int adsRequired) async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      if (mounted) Navigator.pushNamed(context, '/login');
      return;
    }
    
    setState(() => _processingCoins.add(coins));
    
    int adsWatched = 0;
    
    for (int i = 0; i < adsRequired; i++) {
      final ad = await AdMobService.loadRewardedAd();
      if (ad == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load ad ${i + 1}/$adsRequired. Try again later.')),
          );
        }
        break;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Showing ad ${i + 1} of $adsRequired'), duration: Duration(seconds: 1)),
        );
      }
      
      await AdMobService.showRewardedAd(ad);
      adsWatched++;
      
      if (i < adsRequired - 1) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    if (adsWatched > 0) {
      final coinsToAward = (coins * adsWatched / adsRequired).round();
      await WalletService.addCoins(coinsToAward);
      await _loadBalance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You earned $coinsToAward coins!'), backgroundColor: Colors.green),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ads were completed')),
        );
      }
    }
    
    setState(() => _processingCoins.remove(coins));
  }



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Modern app bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.badgeDollarSign,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Buy Coins',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Get coins to unlock premium features',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              title: null,
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: ResponsivePage(
              maxWidth: 900,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            LucideIcons.coins,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Balance',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_balance Coins',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_billingReady && _billingAvailable) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  LucideIcons.shoppingCart,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Buy Coins on Google Play',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Payments are processed through Google Play billing.',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...[
                            {'coins': 10, 'id': GooglePlayBillingService.coins10ProductId},
                            {'coins': 30, 'id': GooglePlayBillingService.coins30ProductId},
                            {'coins': 60, 'id': GooglePlayBillingService.coins60ProductId},
                          ].map((pkg) {
                            final coinsValue = pkg['coins'] as int;
                            final product = GooglePlayBillingService.instance.productForId(pkg['id'] as String);
                            final isProcessing = _processingCoins.contains(coinsValue);
                            // Product not yet loaded from Play Store — disable
                            // the button so the user cannot purchase before
                            // the price is confirmed (avoids currency mismatch).
                            final loadedProduct = product; // promotes to non-nullable below

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.coins, color: Colors.amber.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$coinsValue coins',
                                          style: TextStyle(
                                            color: colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // Show Play Store price or a loading
                                        // indicator — never show a hardcoded
                                        // price when billing is available.
                                        if (loadedProduct != null)
                                          Text(
                                            loadedProduct.price,
                                            style: TextStyle(
                                              color: colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          )
                                        else
                                          const SizedBox(
                                            height: 12,
                                            width: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: (isProcessing || loadedProduct == null)
                                        ? null
                                        : () => _buyCoins(coinsValue),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      minimumSize: const Size(84, 36),
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Buy'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else if (_billingReady) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Google Play billing is available on Android only. On this platform, you can still earn coins by watching ads.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Free coins section - Only way to get coins
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? [Colors.orange.shade900.withValues(alpha: 0.15), Colors.orange.shade800.withValues(alpha: 0.25)]
                            : [Colors.orange.shade50, Colors.orange.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.tv,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Watch Ads to Earn Coins',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Only way to get coins - watch rewarded ads',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.orange.shade200 : Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Coin packages with ads
                        ...[
                          {'coins': 2, 'ads': 1},
                        ].map((pkg) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.coins, color: Colors.amber.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${pkg['coins']} coins',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${pkg['ads']} ads',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _processingCoins.contains(pkg['coins']) ? null : () => _watchAdsForCoins(pkg['coins'] as int, pkg['ads'] as int),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  minimumSize: const Size(80, 32),
                                ),
                                child: _processingCoins.contains(pkg['coins'])
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Watch'),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Usage info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.info,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How to Use Coins',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildUsageItem(LucideIcons.zap, 'Boost Profile (14 days)', '50 coins'),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildUsageItem(IconData icon, String title, String cost) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            cost,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
