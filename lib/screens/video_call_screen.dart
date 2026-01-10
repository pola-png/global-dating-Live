import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/wallet_service.dart';
import '../services/livekit_token_service.dart';
import '../services/appwrite_service.dart';

class VideoCallScreen extends StatefulWidget {
  final Map<String, dynamic>? otherUser;
  final String? callId;
  final bool isReceiver;

  const VideoCallScreen({
    super.key,
    this.otherUser,
    this.callId,
    this.isReceiver = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _loading = true;
  String? _error;
  Room? _room;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isRinging = false;
  RealtimeSubscription? _callSubscription;
  String? _callDocId;

  @override
  void initState() {
    super.initState();
    if (widget.isReceiver) {
      _showIncomingCallDialog();
    } else {
      _initiateCall();
    }
  }

  @override
  void dispose() {
    _callSubscription?.close();
    _room?.disconnect();
    _endCall();
    super.dispose();
  }

  void _showIncomingCallDialog() {
    setState(() => _isRinging = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming Call'),
        content: Text('${widget.otherUser?['fullName'] ?? 'Someone'} is calling you...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _rejectCall();
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acceptCall();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCall() async {
    setState(() => _isRinging = true);
    
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final callId = ID.unique();
      final callDoc = await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.videoCallsCollectionId,
        documentId: callId,
        data: {
          'callerId': userId,
          'receiverId': widget.otherUser?['id'],
          'status': 'ringing',
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      setState(() => _callDocId = callDoc.$id);
      _subscribeToCallStatus();
    } catch (e) {
      setState(() {
        _error = 'Failed to initiate call';
        _loading = false;
      });
    }
  }

  void _subscribeToCallStatus() {
    _callSubscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.videoCallsCollectionId}.documents',
    ]);

    _callSubscription!.stream.listen((event) {
      if (!event.events.any((e) => e.endsWith('.update'))) return;
      final payload = event.payload;
      if (payload['\$id'] != _callDocId) return;

      final status = payload['status'];
      if (status == 'accepted') {
        _startCall();
      } else if (status == 'rejected' || status == 'ended') {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _acceptCall() async {
    const cost = 30;
    final ok = await WalletService.spendCoins(cost);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _error = 'Not enough coins (30 required)';
        _loading = false;
      });
      return;
    }

    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.videoCallsCollectionId,
        documentId: widget.callId!,
        data: {'status': 'accepted'},
      );
      _startCall();
    } catch (_) {}
  }

  Future<void> _rejectCall() async {
    try {
      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.videoCallsCollectionId,
        documentId: widget.callId!,
        data: {'status': 'rejected'},
      );
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startCall() async {
    setState(() => _isRinging = false);
    
    if (!widget.isReceiver) {
      const cost = 30;
      final ok = await WalletService.spendCoins(cost);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _error = 'Not enough coins (30 required)';
          _loading = false;
        });
        return;
      }
    }

    await _connectToRoom();
  }

  Future<void> _endCall() async {
    if (_callDocId != null) {
      try {
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.videoCallsCollectionId,
          documentId: _callDocId!,
          data: {'status': 'ended'},
        );
      } catch (_) {}
    }
  }

  Future<void> _connectToRoom() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _loading = false;
        });
        return;
      }

      final roomName = widget.callId ?? _callDocId ?? 'call-$userId-${widget.otherUser?['id'] ?? 'unknown'}';
      final token = await LiveKitTokenService.fetchToken(
        roomName: roomName,
        identity: userId,
        isHost: true,
      );

      if (token == null) {
        setState(() {
          _error = 'Failed to get call token';
          _loading = false;
        });
        return;
      }

      final room = Room();
      await room.connect(
        'wss://global-dating-d3im4k9p.livekit.cloud',
        token,
      );

      await room.localParticipant?.setCameraEnabled(true);
      await room.localParticipant?.setMicrophoneEnabled(true);

      setState(() {
        _room = room;
        _isConnected = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to connect: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    if (_room?.localParticipant != null) {
      final newState = !_isMuted;
      await _room!.localParticipant!.setMicrophoneEnabled(!newState);
      setState(() => _isMuted = newState);
    }
  }

  Future<void> _toggleVideo() async {
    if (_room?.localParticipant != null) {
      final newState = !_isVideoOff;
      await _room!.localParticipant!.setCameraEnabled(!newState);
      setState(() => _isVideoOff = newState);
    }
  }

  Widget _buildVideoView() {
    if (!_isConnected || _room == null) {
      return const Center(
        child: Text(
          'Connecting to call...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final participants = [
      _room!.localParticipant!,
      ..._room!.remoteParticipants.values,
    ];

    if (participants.length == 1) {
      final localTrack = _room!.localParticipant?.videoTrackPublications
          .where((pub) => pub.track != null)
          .firstOrNull
          ?.track;
      
      if (localTrack != null) {
        return VideoTrackRenderer(
          localTrack,
          fit: VideoViewFit.cover,
        );
      }
    } else if (participants.length == 2) {
      final remoteTrack = _room!.remoteParticipants.values.first
          .videoTrackPublications
          .where((pub) => pub.track != null)
          .firstOrNull
          ?.track;
      
      final localTrack = _room!.localParticipant?.videoTrackPublications
          .where((pub) => pub.track != null)
          .firstOrNull
          ?.track;

      return Stack(
        children: [
          if (remoteTrack != null)
            Positioned.fill(
              child: VideoTrackRenderer(
                remoteTrack,
                fit: VideoViewFit.cover,
              ),
            ),
          if (localTrack != null)
            Positioned(
              top: 20,
              right: 20,
              width: 120,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: VideoTrackRenderer(
                    localTrack,
                    fit: VideoViewFit.cover,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return const Center(
      child: Text(
        'Waiting for video...',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRinging && !widget.isReceiver) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Calling ${widget.otherUser?['fullName'] ?? 'User'}...',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Call with ${widget.otherUser?['fullName'] ?? 'User'}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.phoneOff, color: Colors.red),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: _buildVideoView(),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FloatingActionButton(
                            onPressed: _toggleMute,
                            backgroundColor: _isMuted ? Colors.red : Colors.white24,
                            child: Icon(
                              _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                              color: Colors.white,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: () => Navigator.pop(context),
                            backgroundColor: Colors.red,
                            child: const Icon(
                              LucideIcons.phoneOff,
                              color: Colors.white,
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: _toggleVideo,
                            backgroundColor: _isVideoOff ? Colors.red : Colors.white24,
                            child: Icon(
                              _isVideoOff ? LucideIcons.videoOff : LucideIcons.video,
                              color: Colors.white,
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
