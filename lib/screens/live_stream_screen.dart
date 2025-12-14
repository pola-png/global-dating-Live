import 'package:appwrite/appwrite.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../config/livekit_config.dart';
import '../services/appwrite_service.dart';
import '../services/livekit_token_service.dart';
import '../services/wallet_service.dart';
import '../components/responsive_page.dart';
import '../services/appwrite_service.dart' show SessionStore;

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
        'liveStreamId': 'gdc-live-${DateTime.now().millisecondsSinceEpoch}',
        'hostId': user.$id,
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
    if (_busy) return;
    setState(() => _busy = true);

    // If the current user is the host, let them re-enter the live room for free.
    final currentUserId = await SessionStore.ensureUserId();
    final isHost = currentUserId != null && session['hostId'] == currentUserId;

    if (!isHost) {
      const cost = 20;
      final ok = await WalletService.spendCoins(cost);
      if (!mounted) return;
      if (!ok) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Need 20 coins to join a live stream.')),
        );
        return;
      }
    }

    if (!isHost) {
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
    }

    if (mounted) {
      setState(() => _busy = false);
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(session: session, isHost: isHost),
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
              subtitle: const Text(
                'Cost: 50 coins to start. Viewers pay 20 coins to join.',
              ),
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
                    ? const Center(
                        child:
                            Text('No live sessions yet. Be the first to go live!'),
                      )
                    : ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          return Card(
                            child: ListTile(
                              leading: const Icon(LucideIcons.video),
                              title: Text(session['title'] ?? 'Live stream'),
                              subtitle: Text(
                                'Host: ${session['hostName'] ?? 'Unknown'} · ${session['viewerCount'] ?? 0} viewers',
                              ),
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
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  RealtimeSubscription? _subscription;
  bool _sending = false;

  // Local camera (used for placeholder preview when LiveKit is not yet wired).
  CameraController? _cameraController;
  Future<void>? _cameraInit;
  bool _cameraError = false;

  // LiveKit room stub (connects to media server; UI still uses camera preview for now).
  Room? _liveKitRoom;
  bool _lkConnecting = false;
  bool _lkConnected = false;

  String get _liveStreamId => widget.session['id'] as String;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
    _connectLiveKit();
    if (widget.isHost && !kIsWeb) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    _messageController.dispose();
    _cameraController?.dispose();
    _liveKitRoom?.disconnect();
    super.dispose();
  }

  Future<void> _connectLiveKit() async {
    if (_lkConnecting || _lkConnected) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    _lkConnecting = true;
    setState(() {});

    final roomName =
        (widget.session['liveStreamId'] as String?) ?? (widget.session['id'] as String);

    final token = await LiveKitTokenService.fetchToken(
      roomName: roomName,
      identity: userId,
      isHost: widget.isHost,
    );

    if (token == null) {
      _lkConnecting = false;
      setState(() {});
      return;
    }

    final room = Room();

    try {
      await room.connect(LiveKitConfig.wsUrl, token);
      _liveKitRoom = room;
      _lkConnected = true;
    } catch (_) {
      // Silent failure for now; camera placeholder still works.
    } finally {
      _lkConnecting = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Widget _buildLiveVideo() {
    // If LiveKit is connected, prefer rendering LiveKit video.
    if (_lkConnected && _liveKitRoom != null) {
      final room = _liveKitRoom!;

      // For viewers: show the first remote participant's video.
      if (!widget.isHost && room.remoteParticipants.isNotEmpty) {
        final remote = room.remoteParticipants.values.first;
        final pubs = remote.videoTrackPublications;
        if (pubs.isNotEmpty && pubs.first.track != null) {
          final track = pubs.first.track!;
          return VideoTrackRenderer(
            track,
            fit: VideoViewFit.cover,
          );
        }
      }

      // For host: show their own published video track.
      final local = room.localParticipant;
      final localPubs = local?.videoTrackPublications ?? const [];
      if (localPubs.isNotEmpty && localPubs.first.track != null) {
        final track = localPubs.first.track!;
        return VideoTrackRenderer(
          track,
          fit: VideoViewFit.cover,
        );
      }

      // Fallback text if LiveKit has no tracks yet.
      return const Center(
        child: Text(
          'Connected to live video.\nWaiting for video tracks...',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // While connecting to LiveKit, show spinner.
    if (_lkConnecting) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
        ),
      );
    }

    // If LiveKit is not available, fall back to local camera preview for host.
    if (widget.isHost && !kIsWeb) {
      if (_cameraController == null || _cameraInit == null) {
        return const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      }
      return FutureBuilder<void>(
        future: _cameraInit,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            );
          }
          if (snapshot.hasError || _cameraError) {
            return const Center(
              child: Text(
                'Camera not available.\nUse chat below to talk in real time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return CameraPreview(_cameraController!);
        },
      );
    }

    // Viewer fallback when nothing else is ready.
    return const Center(
      child: Text(
        'Connecting to live session...',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Future<void> _initCamera() async {
    if (kIsWeb) return;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = true);
        }
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      _cameraController = controller;
      _cameraInit = controller.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = true);
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveMessagesCollectionId,
        queries: [
          Query.equal('liveStreamId', _liveStreamId),
          Query.orderDesc('createdAt'),
        ],
      );
      setState(() {
        _messages
          ..clear()
          ..addAll(res.documents.map((d) => {
                ...d.data,
                'id': d.$id,
              }).toList().reversed);
      });
    } catch (_) {
      // Ignore; chat is best-effort.
    }
  }

  void _subscribeRealtime() {
    _subscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.liveMessagesCollectionId}.documents',
    ]);

    _subscription!.stream.listen((event) {
      if (!event.events.any((e) => e.endsWith('.create'))) return;
      final payload = event.payload;
      if (payload['liveStreamId'] != _liveStreamId) return;

      setState(() {
        _messages.add({
          ...payload,
          'id': payload['\$id'],
        });
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    try {
      setState(() => _sending = true);
      final user = await AppwriteService.account.get();

      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveMessagesCollectionId,
        documentId: ID.unique(),
        data: {
          'liveStreamId': _liveStreamId,
          'senderId': user.$id,
          'senderName': user.name,
          'text': text,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      _messageController.clear();
    } catch (_) {
      // Ignore errors for now.
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session['title'] ?? 'Live'),
      ),
      body: Stack(
        children: [
          // Full-screen live area (like TikTok live).
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildLiveVideo(),
            ),
          ),

          // Top overlay with host / viewer info and End/Leave button.
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mic, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isHost ? 'You are live' : 'Watching live',
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.session['viewerCount'] ?? 0} viewers',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(widget.isHost ? 'End' : 'Leave'),
                  ),
                ],
              ),
            ),
          ),

          // Bottom overlay with chat list and input placeholder.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 160,
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text(
                                'No messages yet. Start the conversation!',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final sender =
                                    (msg['senderName'] as String?) ?? 'User';
                                final text =
                                    (msg['text'] as String?) ?? '';
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    LucideIcons.messageCircle,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                  title: Text(
                                    '$sender: $text',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      enabled: !_sending,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black54,
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          LucideIcons.messageCircle,
                          color: Colors.white70,
                        ),
                        suffixIcon: IconButton(
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white38,
                                  ),
                                )
                              : const Icon(
                                  LucideIcons.send,
                                  color: Colors.white38,
                                ),
                          onPressed: _sending ? null : _sendMessage,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
