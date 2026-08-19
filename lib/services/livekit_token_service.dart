import 'dart:convert';
import 'supabase_service.dart';

class LiveKitTokenService {
  static Future<String?> fetchToken({
    required String roomName,
    required String identity,
    required bool isHost,
    String? coHostId,
  }) async {
    try {
      final response = await SupabaseService.client.functions.invoke(
        'livekit-token',
        body: {
          'roomName': roomName,
          'identity': identity,
          'isHost': isHost,
          'coHostId': coHostId,
        },
      );

      if (response.status != 200) {
        return null;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['token'] as String?;
      } else if (data is String) {
        final decoded = jsonDecode(data) as Map<String, dynamic>;
        return decoded['token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
