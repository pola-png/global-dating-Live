import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import '../config/appwrite_config.dart';
import '../config/flutterwave_config.dart';
import 'appwrite_service.dart';
import 'wallet_service.dart';

class PaymentStatusDialog extends StatefulWidget {
  final String paymentId;
  final int coins;
  final Function(bool) onResult;

  const PaymentStatusDialog({
    super.key,
    required this.paymentId,
    required this.coins,
    required this.onResult,
  });

  @override
  State<PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<PaymentStatusDialog> {
  Timer? _timer;
  int _attempts = 0;
  static const int _maxAttempts = 30; // 30 attempts = ~2.5 minutes

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _attempts++;
      final success = await _verifyPayment(widget.paymentId);

      if (success || _attempts >= _maxAttempts) {
        timer.cancel();
        if (success && widget.coins > 0) {
          await WalletService.addCoins(widget.coins);
        }
        widget.onResult(success);
      }
    });
  }

  Future<bool> _verifyPayment(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=$paymentId'),
        headers: {
          'Authorization': 'Bearer ${FlutterwaveConfig.secretKey}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['data']?['status'];

        if (status == 'successful') {
          // Update payment record
          await AppwriteService.databases.updateDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.paymentsCollectionId,
            documentId: paymentId,
            data: {'status': 'completed'},
          );
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Processing Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Checking payment status... (${_attempts * 5}s)'),
          const SizedBox(height: 8),
          const Text(
            'Please complete the payment in the browser window.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            widget.onResult(false);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class FlutterwavePaymentService {
  static Future<bool> payForCoins({
    required BuildContext context,
    required int coins,
    required int price,
  }) async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    // Create payment record
    final paymentId = await _createPaymentRecord(userId, coins, price, 'coins');
    if (paymentId == null) return false;

    try {
      // Create payment with Flutterwave Standard flow (mobile-optimized)
      final response = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/payments'),
        headers: {
          'Authorization': 'Bearer ${FlutterwaveConfig.secretKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tx_ref': paymentId,
          'amount': price.toString(),
          'currency': FlutterwaveConfig.currency,
          // Remove redirect_url for mobile apps - we'll handle completion via polling
          'customer': {
            'email': 'user@globaldatingchat.com',
            'name': 'User',
          },
          'customizations': {
            'title': 'Global Dating Chat',
            'description': '$coins coins purchase',
            'logo': 'https://globaldatingchat.com/logo.png',
          },
          // Add payment options for better mobile support
          'payment_options': 'card,mobilemoney,ussd',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final paymentLink = data['data']?['link'];

        if (paymentLink != null && context.mounted) {
          final uri = Uri.parse(paymentLink);
          final launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);

          if (launched) {
            return await _waitForPaymentConfirmation(context, paymentId, coins);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create payment: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }

    return false;
  }

  static Future<bool> payForFastMatch({
    required BuildContext context,
  }) async {
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    // Create payment record for fast match ($50)
    final paymentId = await _createPaymentRecord(userId, 0, 50, 'fast_match');
    if (paymentId == null) return false;

    try {
      // Create payment with Flutterwave Standard flow (same as coins)
      final response = await http.post(
        Uri.parse('https://api.flutterwave.com/v3/payments'),
        headers: {
          'Authorization': 'Bearer ${FlutterwaveConfig.secretKey}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tx_ref': paymentId,
          'amount': '50',
          'currency': FlutterwaveConfig.currency,
          // No redirect_url for mobile apps
          'customer': {
            'email': 'user@globaldatingchat.com',
            'name': 'User',
          },
          'customizations': {
            'title': 'Global Dating Chat',
            'description': 'Fast Matchmaking Service',
            'logo': 'https://globaldatingchat.com/logo.png',
          },
          // Add payment options for better mobile support
          'payment_options': 'card,mobilemoney,ussd',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final paymentLink = data['data']?['link'];

        if (paymentLink != null && context.mounted) {
          final uri = Uri.parse(paymentLink);
          final launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);

          if (launched) {
            return await _waitForPaymentConfirmation(context, paymentId, 0);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create payment: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment error: $e')),
        );
      }
    }

    return false;
  }

  static Future<String?> _createPaymentRecord(String userId, int coins, int price, String type) async {
    try {
      final doc = await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.paymentsCollectionId,
        documentId: 'unique()',
        data: {
          'userId': userId,
          'coins': coins,
          'price': price,
          'type': type,
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );
      return doc.$id;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _waitForPaymentConfirmation(BuildContext context, String paymentId, int coins) async {
    if (!context.mounted) return false;

    bool? result;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PaymentStatusDialog(
        paymentId: paymentId,
        coins: coins,
        onResult: (success) {
          result = success;
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );

    return result ?? false;
  }
}
