import 'package:appwrite/appwrite.dart';
import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

class NotificationService {
  static RealtimeSubscription? _liveStreamSubscription;
  static Function(Map<String, dynamic>)? _onLiveStreamNotification;
  /// Send notification to specific user
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'notifications',
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'title': title,
          'body': body,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  /// Send notification to all users
  static Future<void> sendToAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await AppwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: 'global_notifications',
        documentId: ID.unique(),
        data: {
          'title': title,
          'body': body,
          'data': data,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {}
  }

  /// Instant live stream notification via realtime
  static Future<void> notifyLiveStreamStart({
    required String streamId,
    required String streamerName,
    required String streamerId,
  }) async {
    await AppwriteService.databases.createDocument(
      databaseId: AppwriteConfig.databaseId,
      collectionId: 'live_stream_notifications',
      documentId: ID.unique(),
      data: {
        'streamId': streamId,
        'streamerName': streamerName,
        'streamerId': streamerId,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Subscribe to live stream notifications
  static void subscribeLiveStreamNotifications(
    Function(Map<String, dynamic>) onNotification,
  ) {
    _onLiveStreamNotification = onNotification;
    _liveStreamSubscription = AppwriteService.realtime.subscribe([
      'databases.${AppwriteConfig.databaseId}.collections.live_stream_notifications.documents'
    ]);
    _liveStreamSubscription!.stream.listen((event) {
      if (event.events.contains('databases.*.collections.*.documents.*.create')) {
        _onLiveStreamNotification?.call(event.payload);
      }
    });
  }

  /// Unsubscribe from live stream notifications
  static void unsubscribeLiveStreamNotifications() {
    _liveStreamSubscription?.close();
    _liveStreamSubscription = null;
    _onLiveStreamNotification = null;
  }

  /// Send notification for new posts (to all users)
  static Future<void> sendNewPostNotification({
    required String authorName,
    required String postContent,
  }) async {
    await sendToAllUsers(
      title: 'New Post from $authorName',
      body: postContent.length > 50 
          ? '${postContent.substring(0, 50)}...' 
          : postContent,
      data: {'type': 'new_post'},
    );
  }

  /// Send notification for app announcements
  static Future<void> sendAnnouncementNotification({
    required String title,
    required String message,
  }) async {
    await sendToAllUsers(
      title: title,
      body: message,
      data: {'type': 'announcement'},
    );
  }
}