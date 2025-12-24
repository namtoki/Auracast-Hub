import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Service for communicating with AWS API Gateway backend.
class ApiService {
  // TODO: Update this after Terraform deployment
  static const String _baseUrl =
      'https://your-api-gateway-url.execute-api.ap-northeast-1.amazonaws.com/prod';

  /// Get authentication token from Cognito.
  Future<String?> _getAuthToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.valueOrNull;
        return tokens?.idToken.raw;
      }
    } catch (e) {
      safePrint('Failed to get auth token: $e');
    }
    return null;
  }

  /// Make authenticated API request.
  Future<http.Response> _authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw ApiException('Not authenticated');
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    switch (method) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return http.put(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return http.delete(uri, headers: headers);
      default:
        throw ApiException('Unknown method: $method');
    }
  }

  // ==================== User Settings ====================

  /// Get user settings from DynamoDB.
  Future<UserSettings?> getUserSettings(String userId) async {
    try {
      final response = await _authenticatedRequest('GET', '/settings/$userId');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UserSettings.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw ApiException('Failed to get settings: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Save user settings to DynamoDB.
  Future<void> saveUserSettings(UserSettings settings) async {
    try {
      final response = await _authenticatedRequest(
        'PUT',
        '/settings/${settings.userId}',
        body: settings.toJson(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ApiException('Failed to save settings: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  // ==================== Device Profiles ====================

  /// Submit device profile for analytics.
  Future<void> submitDeviceProfile(DeviceProfile profile) async {
    try {
      final response = await _authenticatedRequest(
        'POST',
        '/device-profiles',
        body: profile.toJson(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw ApiException(
            'Failed to submit device profile: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Get recommended buffer size for a device model.
  Future<int?> getRecommendedBufferSize(String model, String platform) async {
    try {
      final response = await _authenticatedRequest(
        'GET',
        '/device-profiles/recommended?model=$model&platform=$platform',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['recommendedBufferMs'] as int?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ==================== Sessions ====================

  /// Create a new session (for host).
  Future<String> createSession(Session session) async {
    try {
      final response = await _authenticatedRequest(
        'POST',
        '/sessions',
        body: session.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['sessionId'] as String;
      } else {
        throw ApiException('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Update session state.
  Future<void> updateSession(Session session) async {
    try {
      final response = await _authenticatedRequest(
        'PUT',
        '/sessions/${session.id}',
        body: session.toJson(),
      );

      if (response.statusCode != 200) {
        throw ApiException('Failed to update session: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// End a session.
  Future<void> endSession(String sessionId) async {
    try {
      final response = await _authenticatedRequest(
        'DELETE',
        '/sessions/$sessionId',
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw ApiException('Failed to end session: ${response.statusCode}');
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
