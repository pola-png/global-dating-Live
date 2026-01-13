import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../components/responsive_page.dart';
import '../services/admin_support_service.dart';
import '../services/appwrite_service.dart';

class FastMatchScreen extends StatefulWidget {
  const FastMatchScreen({super.key});

  @override
  State<FastMatchScreen> createState() => _FastMatchScreenState();
}

class _FastMatchScreenState extends State<FastMatchScreen> with AutomaticKeepAliveClientMixin {
  bool _processing = false;

  @override
  bool get wantKeepAlive => true;

  Future<bool> _checkFastMatchStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('fast_match_paid') ?? false;
  }

  Future<void> _openSupportChat() async {
    final prefs = await SharedPreferences.getInstance();
    final chatRoomId = prefs.getString('fast_match_chat_room');
    if (chatRoomId != null && mounted) {
      Navigator.pushNamed(context, '/chat/$chatRoomId');
    }
  }

  Future<void> _startFastMatch() async {
    // Check if user is authenticated
    final userId = await SessionStore.ensureUserId();
    if (userId == null) {
      if (mounted) {
        Navigator.pushNamed(context, '/login');
      }
      return;
    }
    
    setState(() => _processing = true);
    try {
      // Open Flutterwave payment link
      final uri = Uri.parse('https://flutterwave.com/pay/sadj3pd9qk1c');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (launched) {
        // Send message to admin support for approval
        await AdminSupportService.sendMessage(
          'Fast Match Payment Approval Required - User has initiated Fast Match payment. Please verify payment and approve the service.',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment link opened! After payment, admin will verify and approve your Fast Match service within 24 hours.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open payment link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening payment: $e'),
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
    super.build(context);
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
                  children: [
                    Text(
                      'Premium Fast Matchmaking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get personal help from an admin to find high-quality matches faster.',
                      style: TextStyle(
                        fontSize: 16, 
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
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
                  children: [
                    Text(
                      'What you get',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('• 1:1 chat with an admin matchmaker.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    Text('• Profile review and optimization tips.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    Text('• Tailored suggestions of users that match your preferences.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    Text('• Priority responses and safety guidance.', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
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
                  children: [
                    Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$50 (one-time)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This unlocks one dedicated fast matchmaking session with an admin.',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<bool>(
              future: _checkFastMatchStatus(),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Fast Match Active!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _openSupportChat,
                            child: const Text('Open Support Chat'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
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
            Text(
              'Note: Payments are securely handled by Flutterwave. '
              'Admin support will contact you inside the app via a private chat.',
              style: TextStyle(
                fontSize: 12, 
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
