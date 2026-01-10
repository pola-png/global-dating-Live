import 'dart:convert';

import '../services/appwrite_service.dart';

class LiveKitTokenService {
  static Future<String?> fetchToken({
    required String roomName,
    required String identity,
    required bool isHost,
    String? coHostId,
  }) async {
    try {
      // Use Appwrite Functions execution
      final execution = await AppwriteService.functions.createExecution(
        functionId: 'livekit-token',
        body: jsonEncode({
          'roomName': roomName,
          'identity': identity,
          'isHost': isHost,
          'coHostId': coHostId,
        }),
      );

      if (execution.responseStatusCode != 200) {
        return null;
      }

      final data = jsonDecode(execution.responseBody) as Map<String, dynamic>;
      final token = data['token'];
      if (token is String && token.isNotEmpty) {
        return token;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

