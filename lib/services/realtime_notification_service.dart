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

      _subscription!.stream.listen((event) {
        // Only care about new messages.
        if (!event.events.any((e) => e.contains('.create'))) return;

        final payload = event.payload;
        final text = payload['text'] as String? ?? '';
        if (text.isEmpty) return;

        final senderId = payload['senderId'] as String? ?? '';
        // Do not notify for messages without sender or if we cannot access context.
        final context = navigatorKey.currentContext;
        if (context == null) return;

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

