import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'token_storage.dart';

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';
const kSessionExpiredError = 'Session expired. Please sign in again.';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthUser {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String profilePhoto;

  AuthUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.profilePhoto,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        email: json['email'] as String,
        phone: json['phone'] as String,
        fullName: json['full_name'] as String,
        profilePhoto: json['profile_photo'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'profile_photo': profilePhoto,
      };
}

class SignupStartResult {
  final String sessionId;
  final String phone;

  SignupStartResult({
    required this.sessionId,
    required this.phone,
  });
}

class AuthResult {
  final AuthUser user;
  final String access;
  final String refresh;

  AuthResult({
    required this.user,
    required this.access,
    required this.refresh,
  });
}

class AuthService {
  static const _headers = {'Content-Type': 'application/json'};
  static final currentUserNotifier = ValueNotifier<AuthUser?>(null);
  static final TokenStorage _tokenStorage = TokenStorage();
  static bool _isRefreshing = false;
  static final _refreshLock = Object();

  static void clearCurrentUser() {
    currentUserNotifier.value = null;
  }

  static Future<void> clearSession() async {
    await _tokenStorage.clear();
    clearCurrentUser();
  }

  static Future<AuthUser> cacheCurrentUser(AuthUser user) async {
    await _tokenStorage.saveUserJson(jsonEncode(user.toJson()));
    currentUserNotifier.value = user;
    return user;
  }

  static String _extractError(http.Response response) {
    if (response.statusCode == 401) {
      // Only treat as session expired if the body is a JWT/token error.
      // Wrong-credentials 401s have a readable "detail" we should show instead.
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = (body['detail'] ?? '').toString().toLowerCase();
        if (detail.contains('token')) return kSessionExpiredError;
        // Fall through so the real error message is shown (e.g. wrong password).
      } catch (_) {
        return kSessionExpiredError;
      }
    }
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;

      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) return detail.first.toString();

      final nfe = body['non_field_errors'];
      if (nfe is List && nfe.isNotEmpty) return nfe.first.toString();

      const skip = {'detail', 'non_field_errors'};
      for (final entry in body.entries) {
        if (skip.contains(entry.key)) continue;
        final value = entry.value;
        String? msg;
        if (value is List && value.isNotEmpty) msg = value.first.toString();
        if (value is String) msg = value;
        if (msg != null) {
          final label = entry.key[0].toUpperCase() + entry.key.substring(1);
          return '$label: $msg';
        }
      }
    } catch (_) {}

    return 'Something went wrong. Please try again.';
  }

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on AuthException {
      rethrow;
    } on SocketException {
      throw AuthException('Could not reach the server. Check your connection.');
    } catch (e) {
      throw AuthException('Unexpected error: $e');
    }
  }

  static Future<Map<String, String>> authHeaders() async {
    final access = await _tokenStorage.getAccess();

    if (access == null || access.isEmpty) {
      throw AuthException('Sign in required.');
    }

    return {
      ..._headers,
      'Authorization': 'Bearer $access',
    };
  }

  static Future<AuthResult> _refreshToken() async {
    return synchronized(_refreshLock, () async {
      if (_isRefreshing) {
        final access = await _tokenStorage.getAccess();
        if (access != null && access.isNotEmpty) {
          return AuthResult(
            user: AuthUser(
              id: '',
              email: '',
              phone: '',
              fullName: '',
              profilePhoto: '',
            ),
            access: access,
            refresh: await _tokenStorage.getRefresh() ?? '',
          );
        }
        throw AuthException('Please sign in again.');
      }

      _isRefreshing = true;
      try {
        final refresh = await _tokenStorage.getRefresh();
        if (refresh == null || refresh.isEmpty) {
          throw AuthException('Sign in required.');
        }

        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/token/refresh/'),
          headers: _headers,
          body: jsonEncode({'refresh': refresh}),
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final newAccess = body['access'] as String;
          final newRefresh = body['refresh'] as String?;

          await _tokenStorage.save(
            access: newAccess,
            refresh: newRefresh ?? refresh,
          );

          return AuthResult(
            user: AuthUser(
              id: '',
              email: '',
              phone: '',
              fullName: '',
              profilePhoto: '',
            ),
            access: newAccess,
            refresh: newRefresh ?? refresh,
          );
        } else {
          await _tokenStorage.clear();
          clearCurrentUser();
          throw AuthException('Session expired. Please sign in again.');
        }
      } finally {
        _isRefreshing = false;
      }
    });
  }

  static T synchronized<T>(Object lock, T Function() fn) {
    return fn();
  }

  static Future<void> saveAuthResult(AuthResult result) async {
    await _tokenStorage.save(
      access: result.access,
      refresh: result.refresh,
    );
    await cacheCurrentUser(result.user);
  }

  static Future<AuthUser> getCurrentUser() async {
    final userJson = await _tokenStorage.getUserJson();

    if (userJson != null && userJson.isNotEmpty) {
      try {
        final user = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        currentUserNotifier.value = user;
        return user;
      } catch (_) {}
    }

    return _guard(() async {
      final res = await http.get(
        Uri.parse('$_kBaseUrl/auth/me/'),
        headers: await authHeaders(),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        return cacheCurrentUser(user);
      }

      if (res.statusCode == 401) {
        await _handleTokenRefresh();
        final res = await http.get(
          Uri.parse('$_kBaseUrl/auth/me/'),
          headers: await authHeaders(),
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
          return cacheCurrentUser(user);
        }

        await _tokenStorage.clear();
        clearCurrentUser();
        throw AuthException('Session expired. Please sign in again.');
      }

      throw AuthException(_extractError(res));
    });
  }

  static Future<void> _handleTokenRefresh() async {
    try {
      await _refreshToken();
    } catch (_) {
      await _tokenStorage.clear();
      clearCurrentUser();
      throw AuthException('Session expired. Please sign in again.');
    }
  }

  static Future<void> refreshAccessToken() => _handleTokenRefresh();

  static Future<AuthUser> updateProfile({
    required String fullName,
    required String phone,
  }) =>
      _guard(() async {
        final res = await http.patch(
          Uri.parse('$_kBaseUrl/auth/update-profile/'),
          headers: await authHeaders(),
          body: jsonEncode({
            'full_name': fullName,
            'phone': phone,
          }),
        );

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
          return cacheCurrentUser(user);
        }

        if (res.statusCode == 401) {
          await _handleTokenRefresh();
          final res = await http.patch(
            Uri.parse('$_kBaseUrl/auth/update-profile/'),
            headers: await authHeaders(),
            body: jsonEncode({
              'full_name': fullName,
              'phone': phone,
            }),
          );

          if (res.statusCode == 200) {
            final body = jsonDecode(res.body) as Map<String, dynamic>;
            final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
            return cacheCurrentUser(user);
          }

          await _tokenStorage.clear();
          clearCurrentUser();
          throw AuthException('Session expired. Please sign in again.');
        }

        throw AuthException(_extractError(res));
      });

  static Future<AuthUser> updateProfilePhoto(File image) =>
      _guard(() async {
        final headers = await authHeaders();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_kBaseUrl/auth/update-profile-photo/'),
        );

        request.headers.addAll({
          'Authorization': headers['Authorization']!,
        });
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_photo',
            image.path,
          ),
        );

        final streamedResponse = await request.send();
        final res = await http.Response.fromStream(streamedResponse);

        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
          return cacheCurrentUser(user);
        }

        if (res.statusCode == 401) {
          await _handleTokenRefresh();
          final headers = await authHeaders();
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$_kBaseUrl/auth/update-profile-photo/'),
          );

          request.headers.addAll({
            'Authorization': headers['Authorization']!,
          });
          request.files.add(
            await http.MultipartFile.fromPath(
              'profile_photo',
              image.path,
            ),
          );

          final streamedResponse = await request.send();
          final res = await http.Response.fromStream(streamedResponse);

          if (res.statusCode == 200) {
            final body = jsonDecode(res.body) as Map<String, dynamic>;
            final user = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
            return cacheCurrentUser(user);
          }

          await _tokenStorage.clear();
          clearCurrentUser();
          throw AuthException('Session expired. Please sign in again.');
        }

        throw AuthException(_extractError(res));
      });

  static Future<String> forgotPassword(String identifier) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/forgot-password/'),
          headers: _headers,
          body: jsonEncode({'identifier': identifier}),
        );
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['session_id'] as String;
        }
        throw AuthException(_extractError(res));
      });

  static Future<void> verifyResetOtp({
    required String sessionId,
    required String otp,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/verify-reset-otp/'),
          headers: _headers,
          body: jsonEncode({'session_id': sessionId, 'otp': otp}),
        );
        if (res.statusCode == 200) return;
        throw AuthException(_extractError(res));
      });

  static Future<void> resetPassword({
    required String sessionId,
    required String newPassword,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/reset-password/'),
          headers: _headers,
          body: jsonEncode({'session_id': sessionId, 'new_password': newPassword}),
        );
        if (res.statusCode == 200) return;
        throw AuthException(_extractError(res));
      });

  static Future<SignupStartResult> startSignup({
    required String email,
    required String phone,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/start-signup/'),
          headers: _headers,
          body: jsonEncode({'email': email, 'phone': phone}),
        );
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return SignupStartResult(
            sessionId: body['session_id'] as String,
            phone: body['phone'] as String,
          );
        }
        throw AuthException(_extractError(res));
      });

  static Future<void> verifyOtp({
    required String sessionId,
    required String otp,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/verify-otp/'),
          headers: _headers,
          body: jsonEncode({'session_id': sessionId, 'otp': otp}),
        );
        if (res.statusCode == 200) return;
        throw AuthException(_extractError(res));
      });

  static Future<void> resendOtp({required String sessionId}) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/resend-otp/'),
          headers: _headers,
          body: jsonEncode({'session_id': sessionId}),
        );
        if (res.statusCode == 200) return;
        throw AuthException(_extractError(res));
      });

  static Future<AuthResult> completeSignup({
    required String sessionId,
    required String fullName,
    required String password,
    required String transactionPin,
  }) =>
      _guard(() async {
        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/complete-signup/'),
          headers: _headers,
          body: jsonEncode({
            'session_id': sessionId,
            'full_name': fullName,
            'password': password,
            'transaction_pin': transactionPin,
          }),
        );
        if (res.statusCode == 201) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return AuthResult(
            user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
            access: body['access'] as String,
            refresh: body['refresh'] as String,
          );
        }
        throw AuthException(_extractError(res));
      });

  static Future<AuthResult> signIn({
    String? email,
    String? phone,
    required String password,
  }) =>
      _guard(() async {
        final payload = <String, String>{'password': password};
        if (email != null && email.isNotEmpty) payload['email'] = email;
        if (phone != null && phone.isNotEmpty) payload['phone'] = phone;

        final res = await http.post(
          Uri.parse('$_kBaseUrl/auth/sign-in/'),
          headers: _headers,
          body: jsonEncode(payload),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return AuthResult(
            user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
            access: body['access'] as String,
            refresh: body['refresh'] as String,
          );
        }
        throw AuthException(_extractError(res));
      });

  static Future<void> deleteAccount({required String password}) =>
      _guard(() async {
        final res = await http.delete(
          Uri.parse('$_kBaseUrl/auth/delete-account/'),
          headers: await authHeaders(),
          body: jsonEncode({'password': password}),
        );

        if (res.statusCode == 200) {
          await _tokenStorage.clear();
          clearCurrentUser();
          return;
        }

        if (res.statusCode == 401) {
          await _handleTokenRefresh();
          final res = await http.delete(
            Uri.parse('$_kBaseUrl/auth/delete-account/'),
            headers: await authHeaders(),
            body: jsonEncode({'password': password}),
          );

          if (res.statusCode == 200) {
            await _tokenStorage.clear();
            clearCurrentUser();
            return;
          }

          await _tokenStorage.clear();
          clearCurrentUser();
          throw AuthException('Session expired. Please sign in again.');
        }

        throw AuthException(_extractError(res));
      });

  static Future<void> logout({required String refresh}) async {
    try {
      await http.post(
        Uri.parse('$_kBaseUrl/auth/logout/'),
        headers: _headers,
        body: jsonEncode({'refresh': refresh}),
      );
    } catch (_) {}

    await _tokenStorage.clear();
    clearCurrentUser();
  }
}