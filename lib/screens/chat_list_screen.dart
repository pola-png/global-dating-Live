import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../components/avatar_widget.dart';
import '../components/responsive_page.dart';
import '../services/supabase_service.dart';
import '../services/timezone_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_subscription != null) {
      SupabaseService.client.removeChannel(_subscription!);
    }
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final roomsRes = await SupabaseService.client
          .from('chat_rooms')
          .select('*')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .order('last_active', ascending: false);

      final List<Map<String, dynamic>> chatsWithUsers = [];

      for (final room in roomsRes) {
        final roomId = room['id'].toString();
        final otherUserId = room['user1_id'] == userId
            ? room['user2_id'] as String
            : room['user1_id'] as String;

        final profileRes = await SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', otherUserId)
            .maybeSingle();

        if (profileRes == null) continue;

        // Map keys to CamelCase to match UI expectations
        final otherUserMapped = {
          'id': profileRes['id'],
          'fullName': profileRes['full_name'],
          'avatarLetter': profileRes['avatar_letter'] ?? 'U',
          'avatarPath': profileRes['avatar_path'],
        };

        final unreadCountRes = await SupabaseService.client
            .from('messages')
            .select('id')
            .eq('chat_room_id', roomId)
            .eq('sender_id', otherUserId)
            .eq('is_read', false);
            
        final unreadCount = unreadCountRes.length;

        Map<String, dynamic>? lastMessage;
        final lastMessageId = room['last_message_id']?.toString();
        if (lastMessageId != null) {
          try {
            final lastMsgRes = await SupabaseService.client
                .from('messages')
                .select('*')
                .eq('id', lastMessageId)
                .maybeSingle();
            if (lastMsgRes != null) {
              lastMessage = {
                'id': lastMsgRes['id'].toString(),
                'text': lastMsgRes['text'],
                'senderId': lastMsgRes['sender_id'],
                'chatRoomId': lastMsgRes['chat_room_id'],
                'createdAt': lastMsgRes['created_at'],
                'isRead': lastMsgRes['is_read'],
              };
            }
          } catch (_) {}
        }

        chatsWithUsers.add({
          'id': roomId,
          'user1Id': room['user1_id'],
          'user2Id': room['user2_id'],
          'lastMessageId': room['last_message_id'],
          'lastActive': room['last_active'],
          'other_user': otherUserMapped,
          'other_user_id': otherUserId,
          'unread_count': unreadCount,
          'last_message': lastMessage,
        });
      }

      setState(() {
        _chats = chatsWithUsers;
        _filteredChats = chatsWithUsers;
        _isLoading = false;
      });

      _subscribeToUpdates();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates() {
    if (_subscription != null) return;
    _subscription = SupabaseService.client.channel('chat_list_updates');
    _subscription!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        _loadChats();
      },
    ).subscribe();
  }

  void _filterChats() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChats = _chats
          .where((chat) =>
              (chat['other_user']['fullName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query))
          .toList();
    });
  }

  Widget _buildTimestamp(String? timestamp) {
    if (timestamp == null) return const Text('');
    
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 30), (i) => i),
      builder: (context, snapshot) {
        try {
          final now = DateTime.now();
          final messageTime = DateTime.parse(timestamp).toLocal();
          final difference = now.difference(messageTime);

          String timeText;
          
          if (difference.isNegative || difference.inMinutes < 1) {
            timeText = 'Just now';
          } else if (difference.inMinutes < 60) {
            timeText = '${difference.inMinutes}m ago';
          } else if (difference.inHours < 24) {
            timeText = '${difference.inHours}h ago';
          } else if (difference.inDays < 7) {
            final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            timeText = weekdays[messageTime.weekday - 1];
          } else {
            timeText = '${messageTime.day}/${messageTime.month}/${messageTime.year.toString().substring(2)}';
          }
          
          return Text(timeText, style: TextStyle(color: Colors.grey[500], fontSize: 12));
        } catch (e) {
          return Text('Just now', style: TextStyle(color: Colors.grey[500], fontSize: 12));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey,
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/groups');
              break;
            case 2:
              // Already on chat
              break;
            case 3:
              Navigator.pushNamed(context, '/profile');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.users),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.messageCircle),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 960,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary.withOpacity(0.1), colorScheme.surface],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          LucideIcons.messageCircle,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Conversations',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stay connected with your matches',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Modern search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search conversations...',
                      prefixIcon: const Icon(LucideIcons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Chat list
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredChats.isEmpty
                      ? _buildEmptyState()
                      : _buildChatList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: double.infinity,
            height: 16,
            color: Colors.grey[300],
          ),
          subtitle: Container(
            width: 200,
            height: 12,
            color: Colors.grey[300],
          ),
          trailing: Container(
            width: 40,
            height: 12,
            color: Colors.grey[300],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.messageCircle,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation with someone to see it here.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        final otherUser = chat['other_user'];
        final lastMessage = chat['last_message'];
        final unreadCount = chat['unread_count'] as int;

        return ListTile(
          leading: AvatarWidget(
            avatarUrl: otherUser['avatarPath'] as String?,
            photos: otherUser['photos'] != null ? List<String>.from(otherUser['photos']) : null,
            avatarLetter: (otherUser['fullName'] ?? otherUser['name'] ?? 'U').toString().isNotEmpty 
                ? (otherUser['fullName'] ?? otherUser['name'] ?? 'U').toString()[0].toUpperCase() 
                : 'U',
            radius: 25,
          ),
          title: Text(
            otherUser['fullName'] ?? 'Unknown User',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            lastMessage?['text'] ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTimestamp(lastMessage?['createdAt'] as String?),
              if (unreadCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/chat/${chat['id']}',
              arguments: {
                'chatRoom': chat,
                'otherUser': otherUser,
              },
            );
          },
        );
      },
    );
  }
}
