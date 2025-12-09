import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/wallet_service.dart';
import '../components/responsive_page.dart';

class LiveStreamTab extends StatefulWidget {
  const LiveStreamTab({super.key});

  @override
  State<LiveStreamTab> createState() => _LiveStreamTabState();
}

class _LiveStreamTabState extends State<LiveStreamTab> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _subscribeRealtime();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        queries: [
          Query.orderDesc('createdAt'),
        ],
      );
      setState(() {
        _sessions = res.documents
            .map((d) => {
                  ...d.data,
                  'id': d.$id,
                })
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      // Fallback sample for web/demo
      setState(() {
        _sessions = [];
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    final sub = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.liveStreamsCollectionId}.documents',
    ]);

    sub.stream.listen((event) {
      if (event.events.any((e) => e.endsWith('.create') || e.endsWith('.update'))) {
        _loadSessions();
      }
    });
  }

  Future<void> _startLive() async {
    const cost = 50;
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await WalletService.spendCoins(cost);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need 50 coins to go live.')),
      );
      return;
    }

    try {
      final user = await AppwriteService.account.get();
      final insert = {
        'liveStreamId': 'https://example.com/${user.$id}-${DateTime.now().millisecondsSinceEpoch}',
        'hostId': 'https://example.com/${user.$id}',
        'title': 'Live with ${user.name}',
        'hostName': user.name,
        'viewerCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'isLive': true,
      };
      final doc = await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: ID.unique(),
        data: insert,
      );
      final saved = {
        ...doc.data,
        'id': doc.$id,
      };
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(session: saved, isHost: true),
        ),
      );
      await _loadSessions();
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start live stream. Please try again.')),
        );
      }
    }
  }

  Future<void> _join(Map<String, dynamic> session) async {
    const cost = 20;
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await WalletService.spendCoins(cost);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Need 20 coins to join a live stream.')),
      );
      return;
    }

    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: session['id'] as String,
        data: {
          'viewerCount': (session['viewerCount'] ?? 0) + 1,
        },
      );
      await _loadSessions();
    } catch (_) {}

    setState(() => _busy = false);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(session: session, isHost: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      maxWidth: 1000,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(LucideIcons.radioTower),
              title: const Text('Go Live'),
              subtitle: const Text('Cost: 50 coins to start. Viewers pay 20 coins to join.'),
              trailing: ElevatedButton(
                onPressed: _busy ? null : _startLive,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                    ? const Center(child: Text('No live sessions yet. Be the first to go live!'))
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(LucideIcons.video),
                              title: Text(session['title'] ?? 'Live stream'),
                              subtitle: Text('Host: ${session['host_name'] ?? 'Unknown'} • ${session['viewer_count'] ?? 0} viewers'),
                              trailing: ElevatedButton(
                                onPressed: _busy ? null : () => _join(session),
                                child: const Text('Join (20 coins)'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class LiveRoomScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final bool isHost;

  const LiveRoomScreen({
    super.key,
    required this.session,
    required this.isHost,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session['title'] ?? 'Live'),
      ),
      body: ResponsivePage(
        maxWidth: 900,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
                child: const Center(
                  child: Text(
                  'Live video area.\nHook up your streaming provider (Agora, Daily, Jitsi, etc.).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(LucideIcons.mic),
                title: Text(widget.isHost ? 'You are live' : 'Watching live'),
                subtitle: Text(
                  'Host: ${widget.session['host_name'] ?? 'Unknown'} • Viewers: ${widget.session['viewer_count'] ?? 0}',
                ),
                trailing: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isHost ? 'End' : 'Leave'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(LucideIcons.messageCircle),
                    title: Text('Live chat feed placeholder'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}




