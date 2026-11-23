import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import '../security/secure_storage.dart';

class ApiService {
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 6);

  // Helper for Authenticated GET with Auto-Fallback
  static Future<Map<String, dynamic>> get(String url) async {
    return _executeWithFallback((activeUrl) async {
      final token = await SecureStorageService.getAccessToken();
      return await _client.get(
        Uri.parse(activeUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
    }, url);
  }

  // Helper for Authenticated POST with Auto-Fallback
  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    return _executeWithFallback((activeUrl) async {
      final token = await SecureStorageService.getAccessToken();
      return await _client.post(
        Uri.parse(activeUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);
    }, url);
  }

  // Helper for Authenticated PATCH with Auto-Fallback
  static Future<Map<String, dynamic>> patch(String url, Map<String, dynamic> body) async {
    return _executeWithFallback((activeUrl) async {
      final token = await SecureStorageService.getAccessToken();
      return await _client.patch(
        Uri.parse(activeUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(_timeout);
    }, url);
  }

  // Helper for Authenticated DELETE with Auto-Fallback
  static Future<Map<String, dynamic>> delete(String url) async {
    return _executeWithFallback((activeUrl) async {
      final token = await SecureStorageService.getAccessToken();
      return await _client.delete(
        Uri.parse(activeUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);
    }, url);
  }

  // Helper for Authenticated Multipart File Upload with Auto-Fallback
  static Future<Map<String, dynamic>> uploadMultipart(
    String url,
    String filePath, {
    String fieldName = 'photo',
  }) async {
    final token = await SecureStorageService.getAccessToken();
    final uri = Uri.parse(url);
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final file = await http.MultipartFile.fromPath(fieldName, filePath);
    request.files.add(file);

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        if (!ApiEndpoints.isHttps) {
          // Fallback host if initial host fails (local dev only)
          ApiEndpoints.switchHost();
          final fallbackUrl = url.contains('127.0.0.1:5000')
              ? url.replaceAll('127.0.0.1:5000', '192.168.43.199:5000')
              : url.replaceAll('192.168.43.199:5000', '127.0.0.1:5000');
          final fallbackReq = http.MultipartRequest('POST', Uri.parse(fallbackUrl));
          if (token != null) fallbackReq.headers['Authorization'] = 'Bearer $token';
          fallbackReq.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
          final fallbackStream = await fallbackReq.send().timeout(const Duration(seconds: 30));
          final fallbackRes = await http.Response.fromStream(fallbackStream);
          return _handleResponse(fallbackRes);
        } else {
          throw Exception('Unable to reach server. Please check your internet connection.');
        }
      }
      rethrow;
    }
  }

  // Resilient execution with automatic host fallback
  static Future<Map<String, dynamic>> _executeWithFallback(
    Future<http.Response> Function(String url) requestFn,
    String originalUrl,
  ) async {
    try {
      final response = await requestFn(originalUrl);
      return _handleResponse(response);
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        if (!ApiEndpoints.isHttps) {
          // Try fallback host (local dev only)
          ApiEndpoints.switchHost();
          final updatedUrl = originalUrl.contains('127.0.0.1:5000')
              ? originalUrl.replaceAll('127.0.0.1:5000', '192.168.43.199:5000')
              : originalUrl.replaceAll('192.168.43.199:5000', '127.0.0.1:5000');

          try {
            final fallbackResponse = await requestFn(updatedUrl);
            return _handleResponse(fallbackResponse);
          } catch (_) {
            throw Exception('Connection failed. Please check network / adb reverse.');
          }
        } else {
          throw Exception('Connection error. Please check your internet connection.');
        }
      }
      rethrow;
    }
  }

  // Central response parsing
  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      } else {
        final msg = decoded['message'] ?? 'An error occurred';
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception && !e.toString().contains('FormatException')) {
        rethrow;
      }
      throw Exception('Server returned ${response.statusCode}');
    }
  }
}
