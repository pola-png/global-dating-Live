import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:country_picker/country_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../components/report_dialog.dart';
import '../components/responsive_page.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../services/admob_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

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
  BannerAd? _bannerAd;
  bool _adLoaded = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToMessages();
    if (!kIsWeb && SubscriptionService.shouldShowGroupChatAds) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    _bannerAd = AdMobService.createBannerAd()
      ..load().then((_) {
        if (mounted) {
          setState(() {
            _adLoaded = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _bannerAd?.dispose();
    if (_subscription != null) {
      SupabaseService.client.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final metaRes = await SupabaseService.client
          .from('group_metadata')
          .select('member_count')
          .eq('country_slug', widget.countrySlug)
          .maybeSingle();

      if (metaRes != null) {
        _memberCount = metaRes['member_count'] as int? ?? 0;
      } else {
        _memberCount = 0;
      }

      final messagesRes = await SupabaseService.client
          .from('group_messages')
          .select('*')
          .eq('group_id', widget.countrySlug)
          .order('created_at', ascending: true)
          .limit(50);

      final messages = messagesRes.map((d) => {
        'id': d['id'].toString(),
        'text': d['text'],
        'senderId': d['sender_id'],
        'chatRoomId': d['group_id'],
        'createdAt': d['created_at'],
        'senderName': d['sender_name'],
      }).toList();

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
    _subscription = SupabaseService.client.channel('group_messages_${widget.countrySlug}');
    _subscription!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'group_messages',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['group_id'] != widget.countrySlug) return;

        final newMessage = {
          'id': record['id'].toString(),
          'text': record['text'],
          'senderId': record['sender_id'],
          'chatRoomId': record['group_id'],
          'createdAt': record['created_at'],
          'senderName': record['sender_name'],
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
      },
    ).subscribe();
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
    final plan = SubscriptionService.currentPlan;
    if (plan != SubscriptionPlan.premium && plan != SubscriptionPlan.special) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = await SessionStore.ensureUserId();
    if (currentUserId == null) return;

    final tempMessage = {
      'id': 'sending...',
      'text': text,
      'senderId': currentUserId,
      'chatRoomId': widget.countrySlug,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'sending',
    };

    setState(() {
      _messages.add(tempMessage);
    });

    _messageController.clear();
    _scrollToBottom();

    String senderName = 'User';
    try {
      final ownProfile = await SupabaseService.client
          .from('users')
          .select('full_name')
          .eq('id', currentUserId)
          .maybeSingle();
      if (ownProfile != null) {
        senderName = ownProfile['full_name'] ?? 'User';
      }
    } catch (_) {}

    try {
      await SupabaseService.client.from('group_messages').insert({
        'group_id': widget.countrySlug,
        'sender_id': currentUserId,
        'text': text,
        'sender_name': senderName,
        'created_at': tempMessage['createdAt'],
      });
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
            // Banner ad for paid users in group chat alone
            if (_adLoaded && _bannerAd != null && SubscriptionService.shouldShowGroupChatAds)
              Container(
                alignment: Alignment.center,
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AdWidget(ad: _bannerAd!),
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
                        enabled: SubscriptionService.currentPlan == SubscriptionPlan.premium || SubscriptionService.currentPlan == SubscriptionPlan.special,
                        decoration: InputDecoration(
                          hintText: (SubscriptionService.currentPlan == SubscriptionPlan.premium || SubscriptionService.currentPlan == SubscriptionPlan.special)
                              ? 'Type a message...'
                              : 'Upgrade to Premium to send messages',
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
                      onPressed: (SubscriptionService.currentPlan == SubscriptionPlan.premium || SubscriptionService.currentPlan == SubscriptionPlan.special)
                          ? _sendMessage
                          : () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Premium Feature'),
                                  content: const Text(
                                    'Participating in Group Chats is only available on the Premium or Special VIP plan.\n\nUpgrade today to text in group chat channels!',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        Navigator.pushNamed(context, '/paywall');
                                      },
                                      child: const Text('Upgrade'),
                                    ),
                                  ],
                                ),
                              );
                            },
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
    final senderId = message['senderId'] ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getAuthorProfile(senderId),
      builder: (context, snapshot) {
        final author = snapshot.data ?? {};
        final authorName = author['fullName'] ?? 'Unknown User';
        final avatarPath = author['avatarPath'] as String?;
        final photos = author['photos'] as List?;
        String? avatarUrl;
        
        if (photos != null && photos.isNotEmpty) {
          avatarUrl = StorageService.buildFileUrl(photos.first);
        } else if (avatarPath != null && avatarPath.isNotEmpty) {
          avatarUrl = StorageService.buildFileUrl(avatarPath);
        }

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
                  _buildBubbleAvatar(senderId, authorName, avatarUrl, theme),
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
                            '/profile/$senderId',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              authorName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
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
                              : theme.colorScheme.surfaceContainer,
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
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentUser) ...[
                  const SizedBox(width: 8),
                  _buildBubbleAvatar(currentUserId, 'Me', null, theme), // Wait, current user avatar can resolve later or use initial
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubbleAvatar(String? userId, String authorName, String? avatarUrl, ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getAuthorProfile(userId ?? ''),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? {};
        final name = profile['fullName'] ?? authorName;
        final path = profile['avatarPath'] as String?;
        final photos = profile['photos'] as List?;
        String? resolvedUrl = avatarUrl;
        
        if (resolvedUrl == null) {
          if (photos != null && photos.isNotEmpty) {
            resolvedUrl = StorageService.buildFileUrl(photos.first);
          } else if (path != null && path.isNotEmpty) {
            resolvedUrl = StorageService.buildFileUrl(path);
          }
        }

        return GestureDetector(
          onTap: () {
            if (userId != null && userId.isNotEmpty) {
              Navigator.pushNamed(
                context,
                '/profile/$userId',
              );
            }
          },
          child: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: resolvedUrl != null
                ? CachedNetworkImageProvider(resolvedUrl)
                : null,
            child: resolvedUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      }
    );
  }

  Future<Map<String, dynamic>?> _getAuthorProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await SupabaseService.client
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      if (doc != null) {
        return {
          ...doc,
          'id': doc['id'],
          'fullName': doc['full_name'],
          'avatarLetter': doc['avatar_letter'] ?? 'U',
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _showReportDialog(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        reportedUserId: message['senderId'],
        context: 'group_chat',
        contextId: widget.countrySlug,
      ),
    );
  }
}
