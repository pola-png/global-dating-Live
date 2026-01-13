import 'dart:convert';
import 'package:http/http.dart' as http;

class TimezoneService {
  static DateTime? _networkTime;
  static DateTime? _lastSync;
  
  static Future<DateTime> getNetworkTime() async {
    // If we have a recent sync (within 5 minutes), use cached time
    if (_networkTime != null && _lastSync != null) {
      final timeSinceSync = DateTime.now().difference(_lastSync!);
      if (timeSinceSync.inMinutes < 5) {
        final elapsed = DateTime.now().difference(_lastSync!);
        return _networkTime!.add(elapsed);
      }
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _networkTime = DateTime.parse(data['utc_datetime']);
        _lastSync = DateTime.now();
        return _networkTime!;
      }
    } catch (_) {
      // Fallback to local time if network fails
    }
    
    return DateTime.now().toUtc();
  }
  
  static Future<Duration> getTimeDifference(String timestamp) async {
    try {
      final networkTime = await getNetworkTime();
      final messageTime = DateTime.parse(timestamp).toUtc();
      return networkTime.difference(messageTime);
    } catch (_) {
      // Fallback to local time calculation
      final now = DateTime.now().toUtc();
      final messageTime = DateTime.parse(timestamp).toUtc();
      return now.difference(messageTime);
    }
  }
}