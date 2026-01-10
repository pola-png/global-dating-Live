import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'appwrite_service.dart';
import 'messaging_subscription_service.dart';

class PushRegistrationService {
  /// Initialize Firebase and register this device for push notifications.
  /// Automatically subscribes to global notifications.
  static Future<void> registerForPush() async {
    if (kIsWeb) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    try {
      // Initialize Firebase if not already initialized
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;

      // Request permission automatically
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // User denied permission
      }

      // Get FCM token
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      // Auto-subscribe to global notifications
      await MessagingSubscriptionService.subscribeToGlobal(
        userId: userId,
        targetId: token,
      );

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _updateToken(userId, newToken);
      });

    } catch (_) {
      // Silent fail - push notifications are optional
    }
  }

  /// Update token when it refreshes
  static Future<void> _updateToken(String userId, String newToken) async {
    try {
      await MessagingSubscriptionService.subscribeToGlobal(
        userId: userId,
        targetId: newToken,
      );
    } catch (_) {
      // Silent fail
    }
  }

  /// Force re-registration (useful after login)
  static Future<void> forceRegister() async {
    await registerForPush();
  }
}

