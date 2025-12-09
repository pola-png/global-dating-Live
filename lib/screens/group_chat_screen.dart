import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:country_picker/country_picker.dart';
import '../components/report_dialog.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class GroupChatScreen extends StatefulWidget {
  final String countrySlug;
  final Country country;

  const GroupChatScreen({
    super.key,
    required this.countrySlug,
    required this.country,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  int _memberCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = AppwriteService.databases;

      final metaRes = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.groupMetadataCollectionId,
        queries: [
          Query.equal('countrySlug', widget.countrySlug),
        ],
      );

      if (metaRes.documents.isNotEmpty) {
        _memberCount =
            metaRes.documents.first.data['memberCount'] as int? ?? 0;
      } else {
        _memberCount = 0;
      }

      final messagesRes = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'groupmessages',
        queries: [
          Query.equal('countrySlug', widget.countrySlug),
          Query.orderAsc('createdAt'),
          Query.limit(50),
        ],
      );

      final messages = messagesRes.documents
          .map((d) => {
                ...d.data,
                'id': d.$id,
              })
          .toList();

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
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

  void _subscribeToMessages() {
    final sub = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.groupmessages.documents',
    ]);

    sub.stream.listen((event) {
      if (!event.events.any((e) => e.endsWith('.create'))) return;
      final data = event.payload['data'] as Map<String, dynamic>?;
      if (data == null) return;
      if (data['countrySlug'] != widget.countrySlug) return;

      final newMessage = {
        ...data,
        'id': event.payload['\$id'] as String,
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
      }
    });
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

    final tempMessage = {
      'id': 'sending...',
      'text': text,
      'authorId': currentUserId,
      'countrySlug': widget.countrySlug,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'sending',
    };

    setState(() {
      _messages.add(tempMessage);
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'groupmessages',
        documentId: ID.unique(),
        data: {
          'text': text,
          'authorId': currentUserId,
          'countrySlug': widget.countrySlug,
          'createdAt': tempMessage['createdAt'],
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

  String _formatTime(String createdAt) {
    final messageTime = DateTime.parse(createdAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate == today) {
      return '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${messageTime.day}/${messageTime.month} ${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(
                    'https://flagsapi.com/${widget.country.countryCode}/flat/64.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.country.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    '$_memberCount members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
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
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
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
    final isCurrentUser = message['authorId'] == currentUserId;
    final author = message['author'] as Map<String, dynamic>? ?? {};

    return GestureDetector(
      onLongPress: !isCurrentUser ? () => _showReportDialog(message) : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
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
                  '/profile/${message['authorId']}',
                ),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    author['avatarLetter'] ?? 'U',
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
                  if (!isCurrentUser)
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/profile/${message['authorId']}',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          author['fullName'] ?? 'Unknown User',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),
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
                    child: Text(
                      message['text'] ?? '',
                      style: TextStyle(
                        color: isCurrentUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(message['createdAt'] as String),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color,
                      ),
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

  void _showReportDialog(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        reportedUserId: message['authorId'],
        context: 'group_chat',
        contextId: widget.countrySlug,
      ),
    );
  }
}
