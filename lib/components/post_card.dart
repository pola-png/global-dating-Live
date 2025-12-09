import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';
import '../services/storage_service.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Map<String, int> _reactions = {};
  String? _userReaction;

  final Map<String, Color> _bgColors = {
    'gray': const Color(0xFFF3F4F6),
    'white': Colors.white,
    'sky': const Color(0xFFBAE6FD),
    'rose': const Color(0xFFFCE7F3),
    'teal': const Color(0xFFB2F5EA),
    'amber': const Color(0xFFFEF3C7),
    'violet': const Color(0xFFE9D5FF),
    'black': Colors.black,
    'red': const Color(0xFFEF4444),
    'blue': const Color(0xFF3B82F6),
    'green': const Color(0xFF10B981),
  };

  final Map<String, Color> _textColors = {
    'gray': const Color(0xFF1F2937),
    'white': const Color(0xFF0A0A0A),
    'sky': const Color(0xFF1E3A8A),
    'rose': const Color(0xFF9F1239),
    'teal': const Color(0xFF134E4A),
    'amber': const Color(0xFF92400E),
    'violet': const Color(0xFF6B21A8),
    'black': Colors.white,
    'red': Colors.white,
    'blue': Colors.white,
    'green': Colors.white,
  };

  @override
  void initState() {
    super.initState();
    _reactions = {
      'like': widget.post['reactionsLike'] as int? ?? 0,
      'heart': widget.post['reactionsHeart'] as int? ?? 0,
      'laugh': widget.post['reactionsLaugh'] as int? ?? 0,
    };
  }

  String _getTimeAgo(String createdAt) {
    final now = DateTime.now();
    final postTime = DateTime.parse(createdAt);
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _toggleReaction(String reactionType) async {
    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) {
        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
        return;
      }

      setState(() {
        if (_userReaction == reactionType) {
          _reactions[reactionType] = (_reactions[reactionType] ?? 0) - 1;
          _userReaction = null;
        } else {
          if (_userReaction != null) {
            _reactions[_userReaction!] = (_reactions[_userReaction!] ?? 0) - 1;
          }
          _reactions[reactionType] = (_reactions[reactionType] ?? 0) + 1;
          _userReaction = reactionType;
        }
      });

      await AppwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        documentId: widget.post['id'] as String,
        data: {
          'reactionsLike': _reactions['like'] ?? 0,
          'reactionsHeart': _reactions['heart'] ?? 0,
          'reactionsLaugh': _reactions['laugh'] ?? 0,
        },
      );
    } catch (e) {
      setState(() {
        _reactions = {
          'like': widget.post['reactionsLike'] as int? ?? 0,
          'heart': widget.post['reactionsHeart'] as int? ?? 0,
          'laugh': widget.post['reactionsLaugh'] as int? ?? 0,
        };
      });
    }
  }

  Future<void> _deletePost() async {
    try {
      await AppwriteService.databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.postsCollectionId,
        documentId: widget.post['id'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Future<void> _startChat() async {
    try {
      final currentUserId = await SessionStore.ensureUserId();
      if (currentUserId == null) {
        if (mounted) {
          Navigator.pushNamed(context, '/login');
        }
        return;
      }
      
      final otherUserId = widget.post['authorId'] as String?;
      if (otherUserId == null || otherUserId == currentUserId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You cannot chat with yourself')),
          );
        }
        return;
      }

      final db = AppwriteService.databases;

      final direct = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        queries: [
          Query.equal('user1Id', currentUserId),
          Query.equal('user2Id', otherUserId),
        ],
      );

      final inverse = await db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.chatRoomsCollectionId,
        queries: [
          Query.equal('user1Id', otherUserId),
          Query.equal('user2Id', currentUserId),
        ],
      );

      var chatRoomDoc = direct.documents.isNotEmpty
          ? direct.documents.first
          : (inverse.documents.isNotEmpty ? inverse.documents.first : null);

      if (chatRoomDoc == null) {
        chatRoomDoc = await db.createDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.chatRoomsCollectionId,
          documentId: ID.unique(),
          data: {
            'user1Id': currentUserId,
            'user2Id': otherUserId,
            'lastMessageId': null,
            'lastActive': DateTime.now().toIso8601String(),
          },
        );
      }

      final chatRoomId = chatRoomDoc.$id;

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat/$chatRoomId',
          arguments: {
            'chatRoom': {'id': chatRoomId},
            'otherUser': widget.post['author'],
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start chat')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final author = widget.post['author'] ?? {};
    final bgColor =
        _bgColors[widget.post['backgroundColor']] ?? Colors.white;
    final textColor =
        _textColors[widget.post['backgroundColor']] ?? const Color(0xFF0A0A0A);
    final isCurrentUser =
        (SessionStore.userId ?? '') == (widget.post['authorId'] as String?);
    final isBoostActive =
        author['isBoostedActive'] == true || author['isBoosted'] == true;
    final isVerified = author['isVerified'] == true || isBoostActive;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withAlpha(25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/profile/${widget.post['authorId']}',
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(context).primaryColor,
                          backgroundImage:
                              (author['photos'] != null && (author['photos'] as List).isNotEmpty)
                                  ? NetworkImage(
                                      StorageService.buildFileUrl(
                                        (author['photos'] as List).first as String,
                                      ),
                                    )
                                  : null,
                          child: (author['photos'] == null || (author['photos'] as List).isEmpty)
                              ? Text(
                                  author['avatarLetter'] ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/profile/${widget.post['authorId']}',
                          ),
                          child: Text(
                            author['fullName'] ?? 'Unknown User',
                            style: const TextStyle(
                              fontFamily: 'PT Sans',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          Row(
                            children: const [
                              Icon(LucideIcons.badgeCheck, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Verified', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        Text(
                          _getTimeAgo(widget.post['createdAt'] as String),
                          style: TextStyle(
                            fontFamily: 'PT Sans',
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                        icon: const Icon(LucideIcons.moreHorizontal, size: 16),
                        onSelected: (value) {
                          if (value == 'delete') {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Post'),
                                content: const Text('Are you sure you want to delete this post?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _deletePost();
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          } else if (value == 'report') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Post reported')),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (isCurrentUser)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          if (!isCurrentUser)
                            const PopupMenuItem(
                              value: 'report',
                              child: Text('Report'),
                            ),
                        ],
                      ),
                ],
              ),
            ),
            // Content - Photo or Text
            if (widget.post['type'] == 'photo_post' &&
                widget.post['photoPath'] != null &&
                (widget.post['photoPath'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                          StorageService.buildFileUrl(widget.post['photoPath'] as String),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 240),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    widget.post['text'] ?? '',
                    style: TextStyle(
                      fontFamily: 'PT Sans',
                      fontSize: _getFontSize(widget.post['text'] ?? ''),
                      fontWeight: _getFontWeight(widget.post['text'] ?? ''),
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  _buildReactionButton(LucideIcons.thumbsUp, 'like'),
                  const SizedBox(width: 12),
                  _buildReactionButton(LucideIcons.heart, 'heart'),
                  const SizedBox(width: 12),
                  _buildReactionButton(LucideIcons.laugh, 'laugh'),
                  const Spacer(),
                  if (!isCurrentUser)
                    IconButton(
                      onPressed: _startChat,
                      icon: const Icon(LucideIcons.messageSquare, size: 20),
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getFontSize(String text) {
    final wordCount = text.trim().split(RegExp(r'\s+')).length;
    if (wordCount <= 5) return 32;
    if (wordCount <= 10) return 26;
    if (wordCount <= 20) return 22;
    return 18;
  }

  FontWeight _getFontWeight(String text) {
    final wordCount = text.trim().split(RegExp(r'\s+')).length;
    if (wordCount <= 5) return FontWeight.w900;
    if (wordCount <= 10) return FontWeight.w800;
    if (wordCount <= 20) return FontWeight.w700;
    return FontWeight.w600;
  }

  Widget _buildReactionButton(IconData icon, String reactionType) {
    final count = _reactions[reactionType] ?? 0;
    final isSelected = _userReaction == reactionType;

    return TextButton.icon(
      onPressed: () => _toggleReaction(reactionType),
      icon: Icon(icon, size: 16),
      label: count > 0
          ? Text(
              count.toString(),
              style: const TextStyle(
                fontFamily: 'PT Sans',
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            )
          : const SizedBox.shrink(),
      style: TextButton.styleFrom(
        foregroundColor: isSelected
            ? Colors.white
            : Theme.of(context).textTheme.bodySmall?.color,
        backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
