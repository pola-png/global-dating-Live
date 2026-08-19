import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static RealtimeChannel? _liveStreamSubscription;
  static Function(Map<String, dynamic>)? _onLiveStreamNotification;

  /// Send notification to specific user
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Send notification to all users
  static Future<void> sendToAllUsers({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.client.from('global_notifications').insert({
        'title': title,
        'body': body,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Instant live stream notification via realtime
  static Future<void> notifyLiveStreamStart({
    required String streamId,
    required String streamerName,
    required String streamerId,
  }) async {
    try {
      await SupabaseService.client.from('live_stream_notifications').insert({
        'stream_id': streamId,
        'streamer_name': streamerName,
        'streamer_id': streamerId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Subscribe to live stream notifications
  static void subscribeLiveStreamNotifications(
    Function(Map<String, dynamic>) onNotification,
  ) {
    _onLiveStreamNotification = onNotification;
    _liveStreamSubscription = SupabaseService.client.channel('live_stream_notifications_channel');
    _liveStreamSubscription!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'live_stream_notifications',
      callback: (payload) {
        _onLiveStreamNotification?.call(payload.newRecord);
      },
    ).subscribe();
  }

  /// Unsubscribe from live stream notifications
  static void unsubscribeLiveStreamNotifications() {
    if (_liveStreamSubscription != null) {
      SupabaseService.client.removeChannel(_liveStreamSubscription!);
      _liveStreamSubscription = null;
    }
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
    );
  }
}