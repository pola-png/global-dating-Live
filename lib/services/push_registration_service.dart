import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'appwrite_service.dart';
import 'messaging_subscription_service.dart';

class PushRegistrationService {
  /// Initialize Firebase (on non-web) and register this device for push.
  /// Uses FCM token as the target ID for Appwrite Messaging.
  static Future<void> registerForPush() async {
    if (kIsWeb) return;

    final userId = await SessionStore.ensureUserId();
    if (userId == null) return;

    // Initialize Firebase if not already initialized.
    try {
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (_) {
      // If Firebase fails to init, skip push registration.
      return;
    }

    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Permission request failed or not needed.
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    await MessagingSubscriptionService.subscribeToGlobal(
      userId: userId,
      targetId: token,
    );
  }
}

