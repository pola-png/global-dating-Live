import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

enum SubscriptionPlan {
  none,
  basic,
  standard,
  premium,
  special,
}

class SubscriptionService {
  static const String _planPrefKey = 'subscription_plan_tier';
  static SubscriptionPlan _currentPlan = SubscriptionPlan.none;

  static SubscriptionPlan get currentPlan => _currentPlan;

  static bool get hasActiveSubscription => _currentPlan != SubscriptionPlan.none;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final planStr = prefs.getString(_planPrefKey) ?? 'none';
    _currentPlan = _parsePlan(planStr);

    // Sync from database profile if logged in
    final userId = await SessionStore.ensureUserId();
    if (userId != null) {
      try {
        final doc = await SupabaseService.client
            .from('users')
            .select('subscription_plan')
            .eq('id', userId)
            .maybeSingle();
            
        if (doc != null) {
          final dbPlan = doc['subscription_plan'] as String?;
          if (dbPlan != null) {
            _currentPlan = _parsePlan(dbPlan);
            await prefs.setString(_planPrefKey, dbPlan);
          }
        }
      } catch (_) {
        // Fallback to local plan
      }
    }
  }

  static SubscriptionPlan _parsePlan(String planStr) {
    switch (planStr.toLowerCase()) {
      case 'basic':
        return SubscriptionPlan.basic;
      case 'standard':
        return SubscriptionPlan.standard;
      case 'premium':
        return SubscriptionPlan.premium;
      case 'special':
        return SubscriptionPlan.special;
      default:
        return SubscriptionPlan.none;
    }
  }

  static String _planToString(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.basic:
        return 'basic';
      case SubscriptionPlan.standard:
        return 'standard';
      case SubscriptionPlan.premium:
        return 'premium';
      case SubscriptionPlan.special:
        return 'special';
      default:
        return 'none';
    }
  }

  static Future<bool> upgradePlan(SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    final planStr = _planToString(plan);
    
    _currentPlan = plan;
    await prefs.setString(_planPrefKey, planStr);

    final userId = await SessionStore.ensureUserId();
    if (userId != null) {
      try {
        await SupabaseService.client
            .from('users')
            .update({'subscription_plan': planStr})
            .eq('id', userId);
        return true;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  static const int basicConnectionLimit = 5;
  static const int coinCostPerConnection = 10;
  static const String _unlockedConnectionsKey = 'unlocked_connections_list';

  // Check if a paid subscription hides ads on general screens.
  static bool get shouldShowGeneralAds {
    return _currentPlan == SubscriptionPlan.none;
  }

  // Check if a paid subscription displays group-chat ads.
  static bool get shouldShowGroupChatAds {
    return _currentPlan != SubscriptionPlan.none;
  }

  /// Checks if a connection has been unlocked using coins.
  static Future<bool> isConnectionUnlockedWithCoins(String otherUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_unlockedConnectionsKey) ?? [];
    return list.contains(otherUserId);
  }

  /// Unlocks a connection using coins.
  static Future<bool> unlockConnectionWithCoins(String otherUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_unlockedConnectionsKey) ?? [];
    if (!list.contains(otherUserId)) {
      list.add(otherUserId);
      await prefs.setStringList(_unlockedConnectionsKey, list);
    }
    return true;
  }

  // Basic plan allows chatting with up to 5 unique connections, or more if unlocked with coins.
  static Future<bool> canChatWithUser(String otherUserId) async {
    if (_currentPlan == SubscriptionPlan.none) return false;
    if (_currentPlan != SubscriptionPlan.basic) return true;

    // Check if this connection was already unlocked using coins
    if (await isConnectionUnlockedWithCoins(otherUserId)) {
      return true;
    }

    try {
      final userId = await SessionStore.ensureUserId();
      if (userId == null) return false;

      final res = await SupabaseService.client
          .from('chat_rooms')
          .select('user1_id, user2_id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId');

      final activePartners = res.map((row) {
        final u1 = row['user1_id'] as String;
        final u2 = row['user2_id'] as String;
        return u1 == userId ? u2 : u1;
      }).toSet();

      if (activePartners.contains(otherUserId)) {
        return true;
      }

      return activePartners.length < basicConnectionLimit;
    } catch (_) {
      return true; // Fallback in case of network issue
    }
  }
}
