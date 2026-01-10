import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../components/report_dialog.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/admob_service.dart';
import 'video_call_screen.dart';

class IndividualChatScreen extends StatefulWidget {
  final String chatRoomId;
  final Map<String, dynamic> chatRoom;
  final Map<String, dynamic> otherUser;

  const IndividualChatScreen({
    super.key,
    required this.chatRoomId,
    required this.chatRoom,
    required this.otherUser,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> with AutomaticKeepAliveClientMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _replyingTo;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _messageOffset = 0;
  final int _messageLimit = 50;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
    _markMessagesAsRead();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && !_isLoadingMore) {
      _loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollectionId,
        queries: [
          Query.equal('chatRoomId', widget.chatRoomId),
          Query.orderDesc('createdAt'),
          Query.limit(_messageLimit),
        ],
      );

      final messages = res.documents
          .map((d) => {
                ...d.data,
                'id': d.$id,
              })
          .toList();
      messages.sort(
        (a, b) => DateTime.parse(a['createdAt'] as String)
            .compareTo(DateTime.parse(b['createdAt'] as String)),
      );

      if (mounted) {
        setState(() {
          _messages = messages;
          _messageOffset = messages.length;
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('CRITICAL: Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages. Error: $e'),
            duration: const Duration(seconds: 15),
          ),
        );
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    
    if (mounted) {
      setState(() => _isLoadingMore = true);
    }
    
    try {
      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollectionId,
        queries: [
          Query.equal('chatRoomId', widget.chatRoomId),
          Query.orderDesc('createdAt'),
          Query.offset(_messageOffset),
          Query.limit(_messageLimit),
        ],
      );

      final olderMessages = res.documents
          .map((d) => {
                ...d.data,
                'id': d.$id,
              })
          .toList();
      olderMessages.sort(
        (a, b) => DateTime.parse(a['createdAt'] as String)
            .compareTo(DateTime.parse(b['createdAt'] as String)),
      );

      if (mounted) {
        setState(() {
          _messages.insertAll(0, olderMessages);
          _messageOffset += olderMessages.length;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _subscribeToMessages() {
    final sub = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollectionId}.documents',
    ]);

    sub.stream.listen((event) async {
      if (!event.events.any(
        (e) => e.endsWith('.create'),
      )) {
        return;
      }

      final data = event.payload['data'] as Map<String, dynamic>?;
      if (data == null) {
        return;
      }
      if (data['chatRoomId'] != widget.chatRoomId) {
        return;
      }

      final newId = event.payload['\$id'] as String;
      if (_messages.any((m) => m['id'] == newId)) {
        return;
      }

      final newMessage = {
        ...data,
        'id': newId,
      };

      if (mounted) {
        setState(() {
          final index =
              _messages.indexWhere((msg) => msg['id'] == 'sending...');
          if (index != -1) {
            _messages[index] = newMessage;
          } else {
            _messages.add(newMessage);
          }
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    });
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return;

      final res = await AppwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollectionId,
        queries: [
          Query.equal('chatRoomId', widget.chatRoomId),
          Query.equal('isRead', false),
          Query.notEqual('senderId', userId),
        ],
      );

      for (final doc in res.documents) {
        await AppwriteService.databases.updateDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.messagesCollectionId,
          documentId: doc.$id,
          data: {'isRead': true},
        );
      }
    } catch (e) {
      // Ignore errors for read status
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = await SessionStore.ensureUserId();
    if (currentUserId == null) return;

    final createdAt = DateTime.now().toIso8601String();

    final tempMessage = {
      'id': 'sending...',
      'text': text,
      'senderId': currentUserId,
      'chatRoomId': widget.chatRoomId,
      'createdAt': createdAt,
      'isRead': false,
      'status': 'sending',
    };

    if (_replyingTo != null) {
      tempMessage['reply_to'] = _replyingTo!;
    }

    setState(() {
      _messages.add(tempMessage);
      _replyingTo = null;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final db = AppwriteService.databases;

      final msgDoc = await db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.messagesCollectionId,
        documentId: ID.unique(),
        data: {
          'chatRoomId': widget.chatRoomId,
          'senderId': currentUserId,
          'text': text,
          'createdAt': createdAt,
          'replyToId': _replyingTo?['id'],
          'isRead': false,
          'status': 'sent',
        },
      );

      await db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        documentId: widget.chatRoomId,
        data: {
          'lastMessageId': msgDoc.$id,
          'lastActive': createdAt,
        },
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg['id'] == 'sending...');
          if (index != -1) {
            _messages[index]['status'] = 'failed';
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  void _startReply(Map<String, dynamic> message) {
    setState(() {
      _replyingTo = message;
    });
  }

  String _formatTime(String createdAt) {
    final messageTime = DateTime.parse(createdAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate == today) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${messageTime.day}/${messageTime.month} ${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        reportedUserId: widget.otherUser['id'],
        context: 'individual_chat',
        contextId: widget.chatRoomId,
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${widget.otherUser['fullName']}? You will no longer receive messages from them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _blockUser();
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      final blockerId = await SessionStore.ensureUserId();
      if (blockerId == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.blockedUsersCollectionId,
        documentId: ID.unique(),
        data: {
          'blockerId': blockerId,
          'blockedUserId': widget.otherUser['id'],
          'createdAt': DateTime.now().toIso8601String(),
          'reason': null,
          'isTemporary': null,
          'unblockDate': null,
        },
      );
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error blocking user: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            '/profile/${widget.otherUser['id']}',
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    widget.otherUser['avatarLetter'] ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser['fullName'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Tap to view profile',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.video, size: 20),
              ),
              tooltip: 'Video call (30 coins)',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          LucideIcons.video,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text('Video Call'),
                      ],
                    ),
                    content: Text(
                      'Start a video call with ${widget.otherUser['fullName']}?\n\nCost: 30 coins\n\nOr watch an ad for free!',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      if (!kIsWeb)
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ad = await AdMobService.loadRewardedAd();
                            if (ad != null) {
                              final rewarded = await AdMobService.showRewardedAd(ad);
                              if (rewarded && mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(otherUser: widget.otherUser),
                                  ),
                                );
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Ad not available')),
                              );
                            }
                          },
                          child: const Text('Watch Ad'),
                        ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoCallScreen(otherUser: widget.otherUser),
                            ),
                          );
                        },
                        child: const Text('Use Coins'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          PopupMenuButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.moreVertical, size: 20),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(LucideIcons.flag, size: 18),
                    SizedBox(width: 12),
                    Text('Report'),
                  ],
                ),
                onTap: () => _showReportDialog(),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(LucideIcons.userX, size: 18),
                    SizedBox(width: 12),
                    Text('Block'),
                  ],
                ),
                onTap: () => _showBlockDialog(),
              ),
            ],
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 1100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            // Messages area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          if (_isLoadingMore)
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: const CircularProgressIndicator(),
                            ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return _buildModernMessageBubble(_messages[index]);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            // Reply preview
            if (_replyingTo != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _replyingTo!['text'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _cancelReply,
                      icon: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            // Modern message input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(
                          LucideIcons.send,
                          color: Colors.white,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.all(12),
                        ),
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
  }

  Widget _buildModernMessageBubble(Map<String, dynamic> message) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = SessionStore.userId;
    final isCurrentUser = message['senderId'] == currentUserId;
    final sender = message['sender'] ?? {};

    return GestureDetector(
      onDoubleTap: () => _startReply(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: isCurrentUser 
              ? MainAxisAlignment.end 
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/profile/${message['senderId']}',
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      sender['avatarLetter'] ?? 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isCurrentUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      gradient: isCurrentUser 
                          ? LinearGradient(
                              colors: [colorScheme.primary, colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isCurrentUser 
                          ? null
                          : colorScheme.surfaceVariant.withOpacity(0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Reply context
                          if (message['reply_to'] != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isCurrentUser 
                                    ? Colors.white.withOpacity(0.2)
                                    : colorScheme.surface.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrentUser
                                      ? Colors.white.withOpacity(0.3)
                                      : colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                message['reply_to']['text'],
                                style: TextStyle(
                                  color: isCurrentUser 
                                      ? Colors.white.withOpacity(0.8)
                                      : colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          // Message text
                          Text(
                            message['text'] ?? '',
                            style: TextStyle(
                              color: isCurrentUser 
                                  ? Colors.white 
                                  : colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Timestamp and status
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message['createdAt'] as String),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message['status'] == 'failed'
                                ? LucideIcons.xCircle
                                : message['isRead'] == true
                                    ? LucideIcons.checkCheck
                                    : LucideIcons.check,
                            size: 14,
                            color: message['status'] == 'failed'
                                ? Colors.red
                                : message['isRead'] == true
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ],
                      ],
                    ),
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
