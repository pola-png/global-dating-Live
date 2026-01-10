import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  static FirebaseAnalytics get instance => _analytics;
  
  // User events
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }
  
  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }
  
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  
  // Ad events
  static Future<void> logAdImpression({
    required String adType,
    required String placement,
  }) async {
    await _analytics.logEvent(
      name: 'ad_impression',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }
  
  static Future<void> logAdClick({
    required String adType,
    required String placement,
  }) async {
    await _analytics.logEvent(
      name: 'ad_click',
      parameters: {
        'ad_type': adType,
        'placement': placement,
      },
    );
  }
  
  static Future<void> logAdRewarded({
    required String placement,
    required int coinsEarned,
  }) async {
    await _analytics.logEvent(
      name: 'ad_rewarded',
      parameters: {
        'placement': placement,
        'coins_earned': coinsEarned,
      },
    );
  }
  
  // Revenue events
  static Future<void> logPurchase({
    required double value,
    required String currency,
    required int coins,
  }) async {
    await _analytics.logPurchase(
      value: value,
      currency: currency,
      parameters: {
        'coins': coins,
      },
    );
  }
  
  // Engagement events
  static Future<void> logStartLiveStream() async {
    await _analytics.logEvent(name: 'start_live_stream');
  }
  
  static Future<void> logJoinLiveStream() async {
    await _analytics.logEvent(name: 'join_live_stream');
  }
  
  static Future<void> logVideoCall() async {
    await _analytics.logEvent(name: 'video_call_started');
  }
  
  static Future<void> logMessageSent() async {
    await _analytics.logEvent(name: 'message_sent');
  }
  
  static Future<void> logPostCreated() async {
    await _analytics.logEvent(name: 'post_created');
  }
}
