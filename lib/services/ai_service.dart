import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AIService {
  static Future<String> generateText(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/ai'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': prompt,
          'type': 'text'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? '';
      } else {
        throw Exception('AI request failed');
      }
    } catch (e) {
      throw Exception('AI service error: $e');
    }
  }

  static Future<String> improveText(String text) async {
    return await generateText(
      'Improve this text to be more engaging and professional: $text'
    );
  }

  static Future<String> generateNewsTitle(String content) async {
    return await generateText(
      'Create a catchy, SEO-friendly news title for this content: $content'
    );
  }

  static Future<String> summarizeNews(String content) async {
    return await generateText(
      'Create a brief, engaging summary of this news article: $content'
    );
  }
}