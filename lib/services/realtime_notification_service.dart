import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class RealtimeNotificationService {
  static RealtimeChannel? _subscription;

  static void start(GlobalKey<NavigatorState> navigatorKey) {
    if (_subscription != null) return;

    try {
      _subscription = SupabaseService.client.channel('messages_notifications_channel');
      _subscription!.onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final record = payload.newRecord;
          final text = record['text'] as String? ?? '';
          if (text.isEmpty) return;

          // Don't show notification for messages sent by current user
          final senderId = record['sender_id'] as String?;
          final currentUserId = await SessionStore.ensureUserId();
          if (senderId == currentUserId) return;

          // Only show notification if current user is part of this chat
          final chatRoomId = record['chat_room_id']?.toString();
          if (chatRoomId == null) return;
          
          try {
            final chatRoom = await SupabaseService.client
                .from('chat_rooms')
                .select('user1_id, user2_id')
                .eq('id', chatRoomId)
                .maybeSingle();
            
            if (chatRoom == null) return;
            
            final user1Id = chatRoom['user1_id'] as String?;
            final user2Id = chatRoom['user2_id'] as String?;
            
            // Only show if current user is participant in this chat
            if (currentUserId != user1Id && currentUserId != user2Id) return;
          } catch (_) {
            return;
          }

          final context = navigatorKey.currentContext;
          if (context == null || !context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'New message: ${text.length > 80 ? '${text.substring(0, 77)}...' : text}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ).subscribe();
    } catch (_) {}
  }

  static void stop() {
    if (_subscription != null) {
      SupabaseService.client.removeChannel(_subscription!);
      _subscription = null;
    }
  }
}
