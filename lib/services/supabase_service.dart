import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://kvxltacnknjjdkbzdiyu.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt2eGx0YWNua25qamRrYnpkaXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3MjkzNDEsImV4cCI6MjA3NjMwNTM0MX0.P82-YGF4_FF3xsLJt5_3jrDObcvSC6zTS-K_Z8ANRBA';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

class SessionStore {
  static const String _loggedKey = 'is_user_logged_in';

  static String? get userId => SupabaseService.client.auth.currentUser?.id;

  static Future<bool> isUserLoggedInLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final localFlag = prefs.getBool(_loggedKey) ?? false;
    return localFlag && SupabaseService.client.auth.currentSession != null;
  }

  static Future<void> markLoggedIn(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedKey, true);
  }

  static Future<void> markLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedKey, false);
    await SupabaseService.client.auth.signOut();
  }

  static Future<String?> ensureUserId() async {
    final current = SupabaseService.client.auth.currentUser;
    if (current != null) {
      await markLoggedIn(current.id);
      return current.id;
    }
    return null;
  }

  static void setUserId(String? id) {
    if (id != null) {
      SharedPreferences.getInstance().then((prefs) => prefs.setBool(_loggedKey, true));
    } else {
      SharedPreferences.getInstance().then((prefs) => prefs.setBool(_loggedKey, false));
    }
  }

  static Future<void> refresh() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) {
      await markLoggedOut();
    } else {
      await markLoggedIn(session.user.id);
    }
  }

  static void clear() {
    SharedPreferences.getInstance().then((prefs) => prefs.setBool(_loggedKey, false));
    SupabaseService.client.auth.signOut();
  }
}
