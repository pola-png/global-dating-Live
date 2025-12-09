import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../components/responsive_page.dart';
import '../services/wallet_service.dart';

class VideoCallScreen extends StatefulWidget {
  final Map<String, dynamic>? otherUser;

  const VideoCallScreen({super.key, this.otherUser});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deductCoins();
  }

  Future<void> _deductCoins() async {
    const cost = 30;
    final ok = await WalletService.spendCoins(cost);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'Not enough coins (30 required).';
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.phoneOff),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 900,
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 320,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Connected with ${widget.otherUser?['fullName'] ?? 'user'}.\nIntegrate your own in-app video when ready.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          leading: const Icon(LucideIcons.activity),
                          title: const Text('Call active'),
                          subtitle: const Text('Using Supabase signaling; add media when ready.'),
                          trailing: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('End Call'),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
