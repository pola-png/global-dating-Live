import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../config/admin_config.dart';
import '../services/appwrite_service.dart';
import '../services/flutterwave_payment_service.dart';
import '../services/admin_support_service.dart';

class FastMatchScreen extends StatefulWidget {
  const FastMatchScreen({super.key});

  @override
  State<FastMatchScreen> createState() => _FastMatchScreenState();
}

class _FastMatchScreenState extends State<FastMatchScreen> {
  bool _processing = false;

  Future<void> _startFastMatch() async {
    setState(() => _processing = true);
    try {
      final ctx = context;
      final paid = await FlutterwavePaymentService.payForFastMatch(
        context: ctx,
      );
      if (!mounted) return;
      if (paid) {
        final userId = await SessionStore.ensureUserId();
        if (userId == null) {
          if (mounted) {
            Navigator.pushReplacementNamed(ctx, '/login');
          }
          return;
        }

        final adminId = AdminConfig.adminUserId;

        final chatRoomId = await AdminSupportService.openAdminChat(ctx);

        try {
          final db = AppwriteService.databases;
          await db.createDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.supportSessionsCollectionId,
            documentId: ID.unique(),
            data: {
              'sessionId': 'fastmatch-${DateTime.now().millisecondsSinceEpoch}',
              'userId': userId,
              'adminId': adminId,
              'chatRoomId': chatRoomId,
              'type': 'fast_match',
              'status': 'open',
              'createdAt': DateTime.now().toIso8601String(),
            },
          );
        } catch (_) {
          // Silent failure; main flow already succeeded.
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fast match payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fast Matchmaking'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ResponsivePage(
        maxWidth: 900,
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Premium Fast Matchmaking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Get personal help from an admin to find high-quality matches faster.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'What you get',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• 1:1 chat with an admin matchmaker.'),
                    Text('• Profile review and optimization tips.'),
                    Text('• Tailored suggestions of users that match your preferences.'),
                    Text('• Priority responses and safety guidance.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$50 (one-time)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'This unlocks one dedicated fast matchmaking session with an admin.',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _startFastMatch,
                icon: _processing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.rocket),
                label: Text(_processing ? 'Processing...' : 'Pay \$50 & Start'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Payments are securely handled by Flutterwave. '
              'Admin support will contact you inside the app via a private chat.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
