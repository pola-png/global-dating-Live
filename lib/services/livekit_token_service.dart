import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/livekit_config.dart';

class LiveKitTokenService {
  static Future<String?> fetchToken({
    required String roomName,
    required String identity,
    required bool isHost,
  }) async {
    final uri = Uri.parse(LiveKitConfig.tokenEndpoint);

    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'roomName': roomName,
        'identity': identity,
        'isHost': isHost,
      }),
    );

    if (res.statusCode != 200) {
      return null;
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
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

