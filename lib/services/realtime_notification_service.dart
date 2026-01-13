import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class RealtimeNotificationService {
  static RealtimeSubscription? _subscription;

  static void start(GlobalKey<NavigatorState> navigatorKey) {
    // Avoid multiple subscriptions.
    if (_subscription != null) return;

    try {
      _subscription = AppwriteService.realtime.subscribe([
        'databases.${AppwriteConfig.databaseId}.collections.${AppwriteConfig.messagesCollectionId}.documents',
      ]);

      _subscription!.stream.listen((event) async {
        if (!event.events.any((e) => e.contains('.create'))) return;

        final payload = event.payload;
        final text = payload['text'] as String? ?? '';
        if (text.isEmpty) return;

        // Don't show notification for messages sent by current user
        final senderId = payload['senderId'] as String?;
        final currentUserId = await SessionStore.ensureUserId();
        if (senderId == currentUserId) return;

        // Only show notification if current user is part of this chat
        final chatRoomId = payload['chatRoomId'] as String?;
        if (chatRoomId == null) return;
        
        try {
          final chatRoom = await AppwriteService.databases.getDocument(
            databaseId: AppwriteConfig.databaseId,
            collectionId: AppwriteConfig.chatRoomsCollectionId,
            documentId: chatRoomId,
          );
          
          final user1Id = chatRoom.data['user1Id'] as String?;
          final user2Id = chatRoom.data['user2Id'] as String?;
          
          // Only show if current user is participant in this chat
          if (currentUserId != user1Id && currentUserId != user2Id) return;
        } catch (_) {
          return; // Chat room not found or error
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
      });
    } catch (_) {
      // Swallow errors silently; notifications are a best-effort enhancement.
    }
  }

  static void stop() {
    _subscription?.close();
    _subscription = null;
  }
}

