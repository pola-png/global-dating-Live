import 'package:flutter/material.dart';
import '../config/admin_config.dart';
import 'supabase_service.dart';

class AdminSupportService {
  static Future<String?> openAdminChat(BuildContext context) async {
    final currentUserId = await SessionStore.ensureUserId();
    if (currentUserId == null) {
      if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
      return null;
    }

    if (AdminConfig.adminUserId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admin user is not configured. Set AdminConfig.adminUserId first.',
            ),
          ),
        );
      }
      return null;
    }

    final otherUserId = AdminConfig.adminUserId;

    try {
      final existingRooms = await SupabaseService.client
          .from('chat_rooms')
          .select('*')
          .or('and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)');

      Map<String, dynamic>? chatRoomDoc;
      if (existingRooms.isNotEmpty) {
        chatRoomDoc = existingRooms.first;
      } else {
        chatRoomDoc = await SupabaseService.client.from('chat_rooms').insert({
          'user1_id': currentUserId,
          'user2_id': otherUserId,
          'last_active': DateTime.now().toIso8601String(),
        }).select().single();
      }

      final chatRoomId = chatRoomDoc['id'].toString();

      Map<String, dynamic>? adminProfile;
      try {
        final doc = await SupabaseService.client
            .from('users')
            .select('*')
            .eq('id', otherUserId)
            .maybeSingle();
        if (doc != null) {
          adminProfile = {
            ...doc,
            'id': doc['id'],
            'fullName': doc['full_name'],
            'avatarLetter': doc['avatar_letter'] ?? 'A',
          };
        }
      } catch (_) {
        adminProfile = null;
      }

      if (!context.mounted) return chatRoomId;

      Navigator.pushNamed(
        context,
        '/chat/$chatRoomId',
        arguments: {
          'chatRoom': {
            'id': chatRoomId,
            'user1Id': chatRoomDoc['user1_id'],
            'user2Id': chatRoomDoc['user2_id'],
            'lastActive': chatRoomDoc['last_active'],
          },
          'otherUser': adminProfile ??
              {
                'id': otherUserId,
                'fullName': 'Admin Support',
                'avatarLetter': 'A',
              },
        },
      );

      return chatRoomId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open admin chat: $e'),
          ),
        );
      }
      return null;
    }
  }

  static Future<void> sendMessage(String message) async {
    debugPrint('Admin support message: $message');
  }
}
