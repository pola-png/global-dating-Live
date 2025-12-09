import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';

import '../config/admin_config.dart';
import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class AdminSupportService {
  static Future<String?> openAdminChat(BuildContext context) async {
    final currentUserId = await SessionStore.ensureUserId();
    if (currentUserId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return null;
    }

    if (AdminConfig.adminUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin user is not configured. Set AdminConfig.adminUserId first.',
          ),
        ),
      );
      return null;
    }

    final otherUserId = AdminConfig.adminUserId;

    try {
      final db = AppwriteService.databases;

      final existing = await db.listDocuments(
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

      var chatRoomDoc = existing.documents.isNotEmpty
          ? existing.documents.first
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

      Map<String, dynamic>? adminProfile;
      try {
        final doc = await db.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.profilesCollectionId,
          documentId: otherUserId,
        );
        adminProfile = doc.data;
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
            ...chatRoomDoc.data,
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
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open admin chat: $e'),
        ),
      );
      return null;
    }
  }
}
