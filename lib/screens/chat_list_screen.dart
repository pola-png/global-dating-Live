import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../components/responsive_page.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _chats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchController.addListener(_filterChats);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final db = AppwriteService.databases;

      final roomsRes = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        queries: [
          Query.orderDesc('lastActive'),
          Query.or([
            Query.equal('user1Id', userId),
            Query.equal('user2Id', userId),
          ]),
        ],
      );

      final List<Map<String, dynamic>> chatsWithUsers = [];

      for (final room in roomsRes.documents) {
        final data = room.data;
        final otherUserId = data['user1Id'] == userId
            ? data['user2Id'] as String
            : data['user1Id'] as String;

      final profileRes = await db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.profilesCollectionId,
        documentId: otherUserId,
      );

        final unreadRes = await db.listDocuments(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.messagesCollectionId,
          queries: [
            Query.equal('chatRoomId', room.$id),
            Query.equal('senderId', otherUserId),
            Query.equal('isRead', false),
          ],
        );

        chatsWithUsers.add({
          'id': room.$id,
          ...data,
          'other_user': profileRes.data,
          'other_user_id': otherUserId,
          'unread_count': unreadRes.total,
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
    final sub = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollectionId}.documents',
    ]);

    sub.stream.listen((event) {
      if (event.events.any((e) => e.endsWith('.create'))) {
        _loadChats();
      }
    });
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

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    final messageTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[messageTime.weekday - 1];
    } else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
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
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your recent conversations.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      prefixIcon: const Icon(LucideIcons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
            otherUser['avatarLetter'] ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
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
              Text(
                _formatTimestamp(lastMessage?['createdAt'] as String?),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
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
