import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _postsKey = 'cached_posts';
  static const String _profilesKey = 'cached_profiles';
  static const String _groupsKey = 'cached_groups';
  static const String _chatsKey = 'cached_chats';
  
  static Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_postsKey, jsonEncode(posts));
  }
  
  static Future<List<Map<String, dynamic>>> getCachedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_postsKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cached));
    }
    return [];
  }
  
  static Future<void> cacheProfiles(Map<String, Map<String, dynamic>> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesKey, jsonEncode(profiles));
  }
  
  static Future<Map<String, Map<String, dynamic>>> getCachedProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profilesKey);
    if (cached != null) {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v)));
    }
    return {};
  }
  
  static Future<void> cacheGroups(List<Map<String, dynamic>> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupsKey, jsonEncode(groups));
  }
  
  static Future<List<Map<String, dynamic>>> getCachedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_groupsKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cached));
    }
    return [];
  }
  
  static Future<void> cacheChats(List<Map<String, dynamic>> chats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatsKey, jsonEncode(chats));
  }
  
  static Future<List<Map<String, dynamic>>> getCachedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_chatsKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(cached));
    }
    return [];
  }
}