import 'dart:async';
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

  // Singleton HTTP client for connection pooling
  static final http.Client _client = http.Client();
  
  // Default timeout duration
  static const Duration _timeout = Duration(seconds: 30);
  
  // Common headers
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };


  /// Global GET request with improved error handling and timeout
  static Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      debugPrint("API GET: $url");
      
      final combinedHeaders = {..._defaultHeaders};
      if (headers != null) combinedHeaders.addAll(headers);
      
      final response = await _client.get(
        url,
        headers: combinedHeaders,
      ).timeout(_timeout);

      return _handleResponse(response, 'GET', endpoint);
    } on SocketException {
      throw ApiException('No internet connection', 'NETWORK_ERROR');
    } on TimeoutException {
      throw ApiException('Request timeout', 'TIMEOUT');
    } catch (e) {
      throw ApiException('GET request failed: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Global POST request with JSON body and improved error handling
  static Future<dynamic> post(String endpoint, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      debugPrint("API POST: $url");
      
      final combinedHeaders = {..._defaultHeaders};
      if (headers != null) combinedHeaders.addAll(headers);

      final response = await _client.post(
        url,
        headers: combinedHeaders,
        body: jsonEncode(data),
      ).timeout(_timeout);

      return _handleResponse(response, 'POST', endpoint);
    } on SocketException {
      throw ApiException('No internet connection', 'NETWORK_ERROR');
    } on TimeoutException {
      throw ApiException('Request timeout', 'TIMEOUT');
    } catch (e) {
      throw ApiException('POST request failed: $e', 'UNKNOWN_ERROR');
    }
  }

  /// PUT request for updates
  static Future<dynamic> put(String endpoint, Map<String, dynamic> data, {Map<String, String>? headers}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      debugPrint("API PUT: $url");
      
      final combinedHeaders = {..._defaultHeaders};
      if (headers != null) combinedHeaders.addAll(headers);

      final response = await _client.put(
        url,
        headers: combinedHeaders,
        body: jsonEncode(data),
      ).timeout(_timeout);

      return _handleResponse(response, 'PUT', endpoint);
    } on SocketException {
      throw ApiException('No internet connection', 'NETWORK_ERROR');
    } on TimeoutException {
      throw ApiException('Request timeout', 'TIMEOUT');
    } catch (e) {
      throw ApiException('PUT request failed: $e', 'UNKNOWN_ERROR');
    }
  }

  /// DELETE request
  static Future<dynamic> delete(String endpoint, {Map<String, String>? headers}) async {
    try {
      final url = Uri.parse('$baseUrl$endpoint');
      debugPrint("API DELETE: $url");
      
      final combinedHeaders = {..._defaultHeaders};
      if (headers != null) combinedHeaders.addAll(headers);

      final response = await _client.delete(
        url,
        headers: combinedHeaders,
      ).timeout(_timeout);

      return _handleResponse(response, 'DELETE', endpoint);
    } on SocketException {
      throw ApiException('No internet connection', 'NETWORK_ERROR');
    } on TimeoutException {
      throw ApiException('Request timeout', 'TIMEOUT');
    } catch (e) {
      throw ApiException('DELETE request failed: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Handle HTTP response with proper error handling
  static dynamic _handleResponse(http.Response response, String method, String endpoint) {
    debugPrint('$method $endpoint - Status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type'] ?? '';
      
      if (contentType.contains('application/json')) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          throw ApiException('Invalid JSON response', 'PARSE_ERROR');
        }
      } else {
        return response.body;
      }
    } else if (response.statusCode == 401) {
      throw ApiException('Unauthorized access', 'UNAUTHORIZED');
    } else if (response.statusCode == 403) {
      throw ApiException('Forbidden access', 'FORBIDDEN');
    } else if (response.statusCode == 404) {
      throw ApiException('Resource not found', 'NOT_FOUND');
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error', 'SERVER_ERROR');
    } else {
      throw ApiException('Request failed with status: ${response.statusCode}', 'HTTP_ERROR');
    }
  }

  /// Dispose the HTTP client
  static void dispose() {
    _client.close();
  }
}

/// Custom exception class for API errors
class ApiException implements Exception {
  final String message;
  final String code;
  
  const ApiException(this.message, this.code);
  
  @override
  String toString() => 'ApiException($code): $message';
}
