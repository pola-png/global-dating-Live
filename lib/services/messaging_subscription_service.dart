import 'package:appwrite/appwrite.dart';

import '../config/messaging_config.dart';
import 'appwrite_service.dart';

class MessagingSubscriptionService {
  /// Subscribe a user to the global topic for app-wide notifications
  static Future<void> subscribeToGlobal({
    required String userId,
    required String targetId,
  }) async {
    if (targetId.isEmpty) return;

    try {
      await AppwriteService.messaging.createSubscriber(
        topicId: MessagingConfig.globalTopicId,
        subscriberId: '${userId}_global',
        targetId: targetId,
      );
    } on AppwriteException {
      // Ignore; subscription is best-effort
    } catch (_) {
      // Ignore unexpected errors
    }
  }
}
