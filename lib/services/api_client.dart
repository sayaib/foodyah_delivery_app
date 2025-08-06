import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  // Use HTTPS for production environments
  static final bool isDebug = kDebugMode;
  
  static final String? baseUrl = Platform.isAndroid
      ? isDebug 
          ? dotenv.env['API_BASE_URL_ANDROID']
          : dotenv.env['API_BASE_URL_ANDROID_PROD'] ?? 'https://api.foodyah.com'
      : isDebug
          ? dotenv.env['API_BASE_URL_IOS']
          : dotenv.env['API_BASE_URL_IOS_PROD'] ?? 'https://api.foodyah.com';


  /// Global GET request
  static Future<dynamic> get(String endpoint) async {

    final url = Uri.parse('$baseUrl$endpoint');
    print("url-server $url");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('GET request failed: ${response.statusCode}');
    }
  }

  /// Global POST request with JSON body
  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final contentType = response.headers['content-type'] ?? '';

        if (contentType.contains('application/json')) {
          return jsonDecode(response.body);
        } else {
          // Handle plain text response (e.g., from res.send())
          return response.body;
        }
      } else {
        throw Exception('POST request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error during POST request: $e');
    }
  }
}
