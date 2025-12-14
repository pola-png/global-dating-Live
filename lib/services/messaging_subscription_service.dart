import 'package:appwrite/appwrite.dart';

import '../config/messaging_config.dart';
import 'appwrite_service.dart';

class MessagingSubscriptionService {
  /// Subscribe a user + device token to the global topic.
  ///
  /// [userId] is the Appwrite account ID.
  /// [targetId] should be the FCM device token for this device.
  static Future<void> subscribeToGlobal({
    required String userId,
    required String targetId,
  }) async {
    if (targetId.isEmpty) return;

    try {
      await AppwriteService.messaging.createSubscriber(
        topicId: MessagingConfig.globalTopicId,
        subscriberId: userId,
        targetId: targetId,
      );
    } on AppwriteException {
      // Ignore; subscription is best-effort and depends on server setup.
    } catch (_) {
      // Ignore unexpected errors for now.
    }
  }
}
