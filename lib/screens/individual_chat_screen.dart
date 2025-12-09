import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../components/report_dialog.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
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

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _replyingTo;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _messageOffset = 0;
  final int _messageLimit = 50;

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            '/profile/${widget.otherUser['id']}',
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  widget.otherUser['avatarLetter'] ?? 'U',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.otherUser['fullName'] ?? 'Unknown User',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.video),
            tooltip: 'Video call (30 coins)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoCallScreen(otherUser: widget.otherUser),
                ),
              );
            },
          ),
          PopupMenuButton(
            icon: const Icon(LucideIcons.moreVertical),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [Icon(LucideIcons.flag), SizedBox(width: 8), Text('Report')],
                ),
                onTap: () => _showReportDialog(),
              ),
              PopupMenuItem(
                child: const Row(
                  children: [Icon(LucideIcons.userX), SizedBox(width: 8), Text('Block')],
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
                  : Column(
                      children: [
                        if (_isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageBubble(_messages[index]);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            // Reply preview
            if (_replyingTo != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                          Text(
                            _replyingTo!['text'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _cancelReply,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
            // Message input (protected from system gesture/nav with SafeArea)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: const Icon(LucideIcons.send),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
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

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final theme = Theme.of(context);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser) ...[
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/profile/${message['senderId']}',
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    sender['avatarLetter'] ?? 'U',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentUser 
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
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
                                  ? Colors.white.withAlpha(50)
                                  : theme.dividerColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message['reply_to']['text'],
                              style: TextStyle(
                                color: isCurrentUser 
                                    ? Colors.white.withAlpha(200)
                                    : theme.colorScheme.onSurface.withAlpha(200),
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
                            color: isCurrentUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Timestamp and status
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message['createdAt'] as String),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodySmall?.color,
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
                            size: 12,
                            color: message['status'] == 'failed'
                                ? Colors.red
                                : message['isRead'] == true
                                    ? theme.colorScheme.primary
                                    : theme.textTheme.bodySmall?.color,
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
