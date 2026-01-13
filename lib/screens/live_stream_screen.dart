import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/avatar_widget.dart';
import '../config/appwrite_config.dart';
import '../config/livekit_config.dart';
import '../services/appwrite_service.dart';
import '../services/livekit_token_service.dart';
import '../services/wallet_service.dart';
import '../services/storage_service.dart';
import '../services/admob_service.dart';
import '../components/responsive_page.dart';

class LiveStreamTab extends StatefulWidget {
  const LiveStreamTab({super.key});

  @override
  State<LiveStreamTab> createState() => _LiveStreamTabState();
}

class _LiveStreamTabState extends State<LiveStreamTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  bool _busy = false;
  bool _watchingAds = false;
  Map<String, dynamic>? _myActiveStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _subscribeRealtime();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final userId = await SessionStore.ensureUserId();
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        queries: [
          Query.equal('isLive', true),
          Query.orderDesc('createdAt'),
        ],
      );
      final sessions = res.documents
          .map((d) => {
                ...d.data,
                'id': d.$id,
              })
          .toList();
      
      Map<String, dynamic>? myStream;
      if (userId != null) {
        myStream = sessions.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s!['hostId'] == userId,
          orElse: () => null,
        );
      }
      
      setState(() {
        _sessions = sessions;
        _myActiveStream = myStream;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _sessions = [];
        _myActiveStream = null;
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
    if (_busy) return;
    
    // Check if user has active stream first
    if (_myActiveStream != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(session: _myActiveStream!, isHost: true),
        ),
      );
      return;
    }
    
    if (kIsWeb) {
      _startLiveWithCoins();
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Live Stream'),
        content: const Text('Cost: 50 coins\n\nOr watch an ad for free!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _watchingAds = true);
              try {
                final ad = await AdMobService.loadRewardedAd();
                if (ad == null) {
                  if (mounted) {
                    setState(() => _watchingAds = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad not available, try again later')),
                    );
                  }
                  return;
                }
                
                final rewarded = await AdMobService.showRewardedAd(ad);
                if (mounted) {
                  setState(() => _watchingAds = false);
                  // Always start stream after ad is shown
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Starting live stream...'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                  );
                  await _startLiveWithoutCost();
                }
              } catch (e) {
                // If ad was shown but callback failed, still start stream
                if (mounted) {
                  setState(() => _watchingAds = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Starting live stream...'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                  );
                  await _startLiveWithoutCost();
                }
              }
            },
            child: const Text('Watch Ad'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startLiveWithCoins();
            },
            child: const Text('Use Coins'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _startLiveWithoutCost() async {
    setState(() {
      _busy = true;
      _watchingAds = false;
    });
    
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          setState(() => _busy = false);
          Navigator.pushNamed(context, '/login');
        }
        return;
      }
      
      if (_myActiveStream != null) {
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(session: _myActiveStream!, isHost: true),
          ),
        );
        return;
      }
      
      final user = await AppwriteService.account.get();
      final docId = ID.unique();
      final insert = {
        'hostId': user.$id,
        'title': user.name,
        'hostName': user.name,
        'viewerCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'isLive': true,
        'liveStreamId': docId,
      };
      
      final doc = await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: docId,
        data: insert,
      );
      
      final saved = {...doc.data, 'id': doc.$id};
      
      // Update local state immediately
      setState(() {
        _myActiveStream = saved;
        _sessions.insert(0, saved);
      });
      
      if (!mounted) return;
      setState(() => _busy = false);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(session: saved, isHost: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start live stream: $e')),
        );
      }
    }
  }
  
  Future<void> _startLiveWithCoins() async {
    setState(() => _busy = true);
    
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
        return;
      }
      
      if (_myActiveStream != null) {
        if (!mounted) return;
        setState(() => _busy = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(session: _myActiveStream!, isHost: true),
          ),
        );
        return;
      }
      
      const cost = 50;
      final user = await AppwriteService.account.get();
      final docId = ID.unique();
      final insert = {
        'hostId': user.$id,
        'title': user.name,
        'hostName': user.name,
        'viewerCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'isLive': true,
        'liveStreamId': docId,
      };
      
      final doc = await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: docId,
        data: insert,
      );
      
      final ok = await WalletService.spendCoins(cost);
      if (!ok) {
        await AppwriteService.databases.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.liveStreamsCollectionId,
          documentId: doc.$id,
        );
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Need 50 coins to go live.')),
        );
      }
        return;
      }
      
      final saved = {...doc.data, 'id': doc.$id};
      
      if (!mounted) return;
      setState(() => _busy = false);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(session: saved, isHost: true),
        ),
      );
      
      await _loadSessions();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start live stream: $e')),
        );
      }
    }
  }

  Future<void> _join(Map<String, dynamic> session) async {
    if (_busy) return;
    
    final currentUserId = await SessionStore.ensureUserId();
    if (currentUserId == null) {
      if (!mounted) return;
      Navigator.pushNamed(context, '/login');
      return;
    }
    
    final isHost = session['hostId'] == currentUserId;
    
    if (isHost) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(session: session, isHost: true),
          ),
        );
      }
      return;
    }
    
    if (kIsWeb) {
      _joinWithCoins(session);
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Live Stream'),
        content: const Text('Cost: 20 coins\n\nOr watch an ad for free!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final ad = await AdMobService.loadRewardedAd();
                if (ad == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ad not available, try again later')),
                    );
                  }
                  return;
                }
                
                final rewarded = await AdMobService.showRewardedAd(ad);
                if (mounted) {
                  // Always join stream after ad is shown
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Joining stream...'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                  );
                  _joinWithoutCost(session);
                }
              } catch (e) {
                // If ad was shown but callback failed, still join
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Joining stream...'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                  );
                  _joinWithoutCost(session);
                }
              }
            },
            child: const Text('Watch Ad'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _joinWithCoins(session);
            },
            child: const Text('Use Coins'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _joinWithoutCost(Map<String, dynamic> session) async {
    setState(() => _busy = true);

    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: session['id'] as String,
        data: {'viewerCount': (session['viewerCount'] ?? 0) + 1},
      );
      await _loadSessions();
    } catch (_) {}

    if (mounted) {
      setState(() => _busy = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveRoomScreen(session: session, isHost: false),
        ),
      );
    }
  }
  
  Future<void> _joinWithCoins(Map<String, dynamic> session) async {
    setState(() => _busy = true);

    try {
      final currentUserId = await SessionStore.ensureUserId();
      if (currentUserId == null) {
        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
        return;
      }
      
      final isHost = session['hostId'] == currentUserId;
      
      if (isHost) {
        if (mounted) {
          setState(() => _busy = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveRoomScreen(session: session, isHost: true),
            ),
          );
        }
        return;
      }

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

      try {
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.liveStreamsCollectionId,
          documentId: session['id'] as String,
          data: {'viewerCount': (session['viewerCount'] ?? 0) + 1},
        );
        await _loadSessions();
      } catch (_) {}

      if (mounted) {
        setState(() => _busy = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveRoomScreen(session: session, isHost: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join live stream: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ResponsivePage(
      maxWidth: 1000,
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Column(
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
                        : Text(_myActiveStream != null ? 'Resume' : 'Start'),
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
                              final isMyStream = _myActiveStream != null && session['id'] == _myActiveStream!['id'];
                              
                              return Card(
                                child: ListTile(
                                  leading: const Icon(LucideIcons.video),
                                  title: Text(session['title'] ?? 'Live stream'),
                                  subtitle: Text(
                                    'Host: ${session['hostName'] ?? 'Unknown'} · ${session['viewerCount'] ?? 0} viewers',
                                  ),
                                  trailing: isMyStream
                                      ? null
                                      : ElevatedButton(
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
          if (_watchingAds)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading ads...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
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

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin, WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeSubscription? _subscription;
  bool _sending = false;
  bool _hasRequestedCoHost = false;
  String? _pendingRequestUserId;
  String? _pendingRequestUserName;

  Room? _liveKitRoom;
  bool _lkConnecting = false;
  bool _lkConnected = false;
  bool _isCoHost = false;
  
  final List<AnimationController> _emojiAnimations = [];
  DateTime? _lastConnectionCheck;
  DateTime? _lastAdTime;
  int _adCountdown = 0;
  Timer? _adTimer;

  String get _liveStreamId => widget.session['id'] as String;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkIfCoHost();
    _loadMessages();
    _subscribeRealtime();
    _subscribeToCoHostRequests();
    _connectLiveKit();
    _startConnectionMonitor();
    _checkAndShowGuide();
    if (!kIsWeb) {
      _lastAdTime = DateTime.now();
      _startAdTimer();
    }
  }

  Future<void> _checkAndShowGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('hasSeenLiveStreamGuide') ?? false;
    if (!hasSeenGuide && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _showGuide();
    }
  }

  void _showGuide() {
    final guides = widget.isHost
        ? [
            {'icon': LucideIcons.video, 'title': 'You\'re Live!', 'desc': 'Your stream is visible to all users'},
            {'icon': LucideIcons.plus, 'title': 'Invite Co-Host', 'desc': 'Tap green + icon next to any viewer to invite them'},
            {'icon': LucideIcons.userCheck, 'title': 'Co-Host Requests', 'desc': 'Viewers can request to join - you\'ll see a popup'},
            {'icon': LucideIcons.heart, 'title': 'Reactions', 'desc': 'Viewers can send floating emoji reactions'},
          ]
        : [
            {'icon': LucideIcons.messageCircle, 'title': 'Chat', 'desc': 'Send messages to interact with host and viewers'},
            {'icon': LucideIcons.reply, 'title': 'Reply', 'desc': 'Swipe right on any message to reply'},
            {'icon': LucideIcons.plus, 'title': 'Request Co-Host', 'desc': 'Tap blue + button on right to request going live with host'},
            {'icon': LucideIcons.heart, 'title': 'Send Reactions', 'desc': 'Tap heart button to send floating emojis'},
          ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GuideDialog(guides: guides),
    );
  }

  Future<void> _checkIfCoHost() async {
    final userId = await SessionStore.ensureUserId();
    _isCoHost = widget.session['coHostId'] == userId;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.close();
    _messageController.dispose();
    _scrollController.dispose();
    _adTimer?.cancel();
    
    if (_liveKitRoom != null) {
      _liveKitRoom!.localParticipant?.setCameraEnabled(false);
      _liveKitRoom!.localParticipant?.setMicrophoneEnabled(false);
      _liveKitRoom!.disconnect();
      _liveKitRoom!.dispose();
    }
    
    for (var controller in _emojiAnimations) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.isHost && (state == AppLifecycleState.paused || state == AppLifecycleState.detached)) {
      _endStream();
    }
  }

  void _startConnectionMonitor() {
    _lastConnectionCheck = DateTime.now();
    Future.delayed(const Duration(seconds: 10), _checkConnection);
  }

  void _checkConnection() {
    if (!mounted || !widget.isHost) return;
    
    final now = DateTime.now();
    if (_liveKitRoom == null || !_lkConnected) {
      if (_lastConnectionCheck != null && now.difference(_lastConnectionCheck!).inSeconds > 60) {
        _endStream();
        return;
      }
    } else {
      _lastConnectionCheck = now;
    }
    
    Future.delayed(const Duration(seconds: 10), _checkConnection);
  }
  
  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final now = DateTime.now();
      final elapsed = now.difference(_lastAdTime!).inSeconds;
      final remaining = 300 - elapsed;
      
      if (remaining <= 60 && remaining > 0) {
        setState(() => _adCountdown = remaining);
      } else if (remaining <= 0) {
        setState(() => _adCountdown = 0);
        _showAdBreak();
      } else {
        if (_adCountdown != 0) setState(() => _adCountdown = 0);
      }
    });
  }
  
  Future<void> _showAdBreak() async {
    _adTimer?.cancel();
    final ad = await AdMobService.loadRewardedAd();
    if (ad != null && mounted) {
      await AdMobService.showRewardedAd(ad);
      _lastAdTime = DateTime.now();
      _startAdTimer();
    } else {
      _lastAdTime = DateTime.now();
      _startAdTimer();
    }
  }

  Future<void> _connectLiveKit() async {
    if (_lkConnecting || _lkConnected) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    setState(() => _lkConnecting = true);

    try {
      final roomName = widget.session['id'] as String;
      final coHostId = widget.session['coHostId'] as String?;
      final token = await LiveKitTokenService.fetchToken(
        roomName: roomName,
        identity: userId,
        isHost: widget.isHost || _isCoHost,
        coHostId: coHostId,
      );

      if (token == null) {
        setState(() => _lkConnecting = false);
        return;
      }

      final room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      
      room.addListener(() {
        if (mounted) setState(() {});
      });
      
      await room.connect(LiveKitConfig.wsUrl, token);
      
      if (widget.isHost || _isCoHost) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
      }
      
      _liveKitRoom = room;
      if (mounted) {
        setState(() {
          _lkConnected = true;
          _lkConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lkConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to live stream: $e')),
        );
      }
    }
  }

  Widget _buildLiveVideo() {
    if (_lkConnected && _liveKitRoom != null) {
      final room = _liveKitRoom!;
      final remoteParticipants = room.remoteParticipants.values.toList();
      
      if ((widget.isHost || _isCoHost) && remoteParticipants.isNotEmpty) {
        final remote = remoteParticipants.first;
        final remoteVideoTrack = remote.videoTrackPublications.where((pub) => pub.track != null).firstOrNull?.track as VideoTrack?;
        final localVideoTrack = room.localParticipant?.videoTrackPublications.where((pub) => pub.track != null).firstOrNull?.track as VideoTrack?;
        
        return Column(
          children: [
            if (localVideoTrack != null)
              Expanded(
                child: VideoTrackRenderer(localVideoTrack, fit: VideoViewFit.cover),
              ),
            if (remoteVideoTrack != null)
              Expanded(
                child: VideoTrackRenderer(remoteVideoTrack, fit: VideoViewFit.cover),
              ),
          ],
        );
      }
      
      if (!widget.isHost && !_isCoHost && remoteParticipants.isNotEmpty) {
        final remote = remoteParticipants.first;
        final videoTrack = remote.videoTrackPublications.where((pub) => pub.track != null).firstOrNull?.track as VideoTrack?;
        if (videoTrack != null) {
          return VideoTrackRenderer(videoTrack, fit: VideoViewFit.cover);
        }
      }

      if (widget.isHost || _isCoHost) {
        final local = room.localParticipant;
        final videoTrack = local?.videoTrackPublications.where((pub) => pub.track != null).firstOrNull?.track as VideoTrack?;
        if (videoTrack != null) {
          return VideoTrackRenderer(videoTrack, fit: VideoViewFit.cover);
        }
      }

      return const Center(
        child: Text(
          'Video starting...',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    if (_lkConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Connecting to live stream...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return const Center(
      child: Text(
        'Live stream unavailable',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  Future<void> _inviteCoHost(String userId, String userName) async {
    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: _liveStreamId,
        data: {
          'coHostId': userId,
          'coHostName': userName,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userName invited as co-host')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to invite co-host')),
        );
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
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _subscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.liveMessagesCollectionId}.documents',
    ]);

    _subscription!.stream.listen((event) {
      if (!event.events.any((e) => e.endsWith('.create'))) return;
      final payload = event.payload;
      if (payload['liveStreamId'] != _liveStreamId) return;

      final newMsgId = payload['\$id'];
      if (_messages.any((m) => m['id'] == newMsgId)) return;

      setState(() {
        _messages.add({
          ...payload,
          'id': newMsgId,
        });
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _subscribeToCoHostRequests() {
    final requestSub = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.liveStreamsCollectionId}.documents',
    ]);

    requestSub.stream.listen((event) {
      if (!event.events.any((e) => e.endsWith('.update'))) return;
      final payload = event.payload;
      if (payload['\$id'] != _liveStreamId) return;

      if (mounted) {
        setState(() {
          _pendingRequestUserId = payload['coHostRequestId'];
          _pendingRequestUserName = payload['coHostRequestName'];
        });
        
        if (widget.isHost && _pendingRequestUserId != null) {
          _showCoHostRequestDialog();
        }
      }
    });
  }

  Future<void> _requestCoHost() async {
    if (_hasRequestedCoHost) return;
    
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;
      
      final user = await AppwriteService.account.get();
      
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: _liveStreamId,
        data: {
          'coHostRequestId': userId,
          'coHostRequestName': user.name,
        },
      );
      
      setState(() => _hasRequestedCoHost = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request')),
        );
      }
    }
  }

  void _showCoHostRequestDialog() {
    if (_pendingRequestUserId == null || _pendingRequestUserName == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Co-Host Request'),
        content: Text('$_pendingRequestUserName wants to join as co-host'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _denyCoHostRequest();
            },
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _approveCoHostRequest();
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveCoHostRequest() async {
    if (_pendingRequestUserId == null) return;
    
    await _inviteCoHost(_pendingRequestUserId!, _pendingRequestUserName ?? 'User');
    await _clearCoHostRequest();
  }

  Future<void> _denyCoHostRequest() async {
    await _clearCoHostRequest();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request denied')),
      );
    }
  }

  Future<void> _clearCoHostRequest() async {
    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveStreamsCollectionId,
        documentId: _liveStreamId,
        data: {
          'coHostRequestId': null,
          'coHostRequestName': null,
        },
      );
      setState(() {
        _pendingRequestUserId = null;
        _pendingRequestUserName = null;
      });
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    setState(() => _sending = true);
    
    try {
      final user = await AppwriteService.account.get();
      
      final profileDoc = await AppwriteService.databases.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: user.$id,
      );
      
      final photos = profileDoc.data['photos'] as List?;
      final avatarFileId = (photos != null && photos.isNotEmpty) ? photos.first as String : '';
      
      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.liveMessagesCollectionId,
        documentId: ID.unique(),
        data: {
          'liveStreamId': _liveStreamId,
          'senderId': user.$id,
          'senderName': user.name,
          'senderAvatar': avatarFileId,
          'text': text,
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      _messageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _sendEmoji(String emoji) async {
    final controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _emojiAnimations.add(controller);
    controller.forward().then((_) {
      _emojiAnimations.remove(controller);
      controller.dispose();
    });
    setState(() {});
  }

  Future<void> _endStream() async {
    if (widget.isHost) {
      try {
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.liveStreamsCollectionId,
          documentId: _liveStreamId,
          data: {'isLive': false},
        );
      } catch (_) {}
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session['title'] ?? 'Live'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: _buildLiveVideo(),
            ),
          ),

          ..._emojiAnimations.asMap().entries.map((entry) {
            final index = entry.key;
            final controller = entry.value;
            return Positioned(
              right: 20 + (index % 3) * 30.0,
              bottom: 80,
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      (index % 2 == 0 ? 1 : -1) * controller.value * 50,
                      -controller.value * 500,
                    ),
                    child: Transform.rotate(
                      angle: controller.value * 6.28 * 2,
                      child: Opacity(
                        opacity: 1 - controller.value,
                        child: Text(
                          '❤️',
                          style: TextStyle(fontSize: 30 + (controller.value * 10)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),

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
                  if (!kIsWeb && _adCountdown > 0) ...[ 
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ad in ${_adCountdown}s',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _endStream,
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

          if (!widget.isHost && !_isCoHost)
            Positioned(
              right: 16,
              bottom: 200,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Request Co-Host'),
                      content: const Text('Send request to join live with the host?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _requestCoHost();
                          },
                          child: const Text('Send Request'),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(LucideIcons.plus, color: Colors.white, size: 28),
                ),
              ),
            ),

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
                    Colors.black.withValues(alpha: 0.7),
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
                              controller: _scrollController,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final sender = (msg['senderName'] as String?) ?? 'User';
                                final text = (msg['text'] as String?) ?? '';
                                final avatarFileId = (msg['senderAvatar'] as String?) ?? '';
                                final senderId = (msg['senderId'] as String?) ?? '';
                                
                                return Dismissible(
                                  key: Key(msg['id'] ?? index.toString()),
                                  direction: DismissDirection.startToEnd,
                                  confirmDismiss: (direction) async {
                                    setState(() {});
                                    _messageController.text = '@$sender ';
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Icon(LucideIcons.reply, color: Colors.white),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => Navigator.pushNamed(context, '/profile/$senderId'),
                                          child: AvatarWidget(
                                            avatarUrl: avatarFileId.isNotEmpty ? avatarFileId : null,
                                            photos: null,
                                            avatarLetter: sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
                                            radius: 14,
                                          ),
                                        ),
                                        if (widget.isHost && senderId != widget.session['hostId'] && senderId != widget.session['coHostId'])
                                          GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: Text('Invite $sender?'),
                                                  content: const Text('Invite as co-host to go live together?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(ctx);
                                                        _inviteCoHost(senderId, sender);
                                                      },
                                                      child: const Text('Invite'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(LucideIcons.plus, size: 12, color: Colors.white),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '$sender: ',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: text,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            enabled: !_sending,
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _sendMessage(),
                            onChanged: (_) => setState(() {}),
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
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : _messageController.text.trim().isNotEmpty
                                    ? const Icon(LucideIcons.send, color: Colors.white)
                                    : const Text('❤️', style: TextStyle(fontSize: 28)),
                            onPressed: _sending
                                ? null
                                : _messageController.text.trim().isNotEmpty
                                    ? _sendMessage
                                    : () => _sendEmoji('❤️'),
                          ),
                        ),
                      ],
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

class _GuideDialog extends StatefulWidget {
  final List<Map<String, dynamic>> guides;

  const _GuideDialog({required this.guides});

  @override
  State<_GuideDialog> createState() => _GuideDialogState();
}

class _GuideDialogState extends State<_GuideDialog> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenLiveStreamGuide', true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 320,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Quick Guide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: widget.guides.length,
                itemBuilder: (context, index) {
                  final guide = widget.guides[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(guide['icon'] as IconData, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        guide['title'] as String,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guide['desc'] as String,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.guides.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.blue : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage < widget.guides.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  child: Text(_currentPage < widget.guides.length - 1 ? 'Next' : 'Got it!'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
