import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components/responsive_page.dart';
import '../services/wallet_service.dart';
import '../services/flutterwave_payment_service.dart';

class CoinPurchaseScreen extends StatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  State<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends State<CoinPurchaseScreen> {
  bool _isProcessing = false;
  int _balance = 0;

  final _packages = const [
    {'coins': 60, 'price': 1},
    {'coins': 400, 'price': 7},
    {'coins': 1000, 'price': 13},
    {'coins': 5000, 'price': 38},
    {'coins': 10000, 'price': 50},
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await WalletService.getBalance();
    if (mounted) setState(() => _balance = balance);
  }

  Future<void> _purchase(int coins, int price) async {
    setState(() => _isProcessing = true);
    try {
      final paid = await FlutterwavePaymentService.payForCoins(
        context: context,
        coins: coins,
        price: price,
      );

      if (paid) {
        await WalletService.addCoins(coins);
        await _loadBalance();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment successful. $coins coins added.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled or failed.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Coins'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ResponsivePage(
        maxWidth: 900,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons.badgeDollarSign, color: Colors.green),
                title: const Text('Current Balance'),
                subtitle: const Text('Coins available to spend'),
                trailing: Text(
                  '$_balance',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a package',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                itemCount: _packages.length,
                itemBuilder: (context, index) {
                  final pkg = _packages[index];
                  return _buildPackageCard(pkg['coins'] as int, pkg['price'] as int);
                },
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Costs: Video call 30 coins, Create live 50 coins, Join live 20 coins, Boost profile 50 coins.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageCard(int coins, int price) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$coins Coins',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('\$$price', style: const TextStyle(fontSize: 16)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _purchase(coins, price),
                child: _isProcessing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
