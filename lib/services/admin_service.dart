import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

const _kBaseUrl = 'https://web-production-b557d.up.railway.app/api';

class AdminException implements Exception {
  final String message;
  AdminException(this.message);

  @override
  String toString() => message;
}

// ── Models ────────────────────────────────────────────────────────────────────

class AdminUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String ngnBalance;
  final bool isActive;
  final String createdAt;
  final String profilePhoto;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.ngnBalance,
    required this.isActive,
    required this.createdAt,
    required this.profilePhoto,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'].toString(),
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        ngnBalance: json['ngn_balance']?.toString() ?? '0.00',
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String,
        profilePhoto: json['profile_photo']?.toString() ?? '',
      );

  AdminUser copyWith({bool? isActive}) => AdminUser(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        ngnBalance: ngnBalance,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        profilePhoto: profilePhoto,
      );
}

class AdminUsersResult {
  final int total;
  final int active;
  final int blacklisted;
  final List<AdminUser> users;

  const AdminUsersResult({
    required this.total,
    required this.active,
    required this.blacklisted,
    required this.users,
  });
}

class CryptoFee {
  final int id;
  final String feeType;
  final double flatUsd;
  final double percent;
  final bool isActive;

  const CryptoFee({
    required this.id,
    required this.feeType,
    required this.flatUsd,
    required this.percent,
    required this.isActive,
  });

  factory CryptoFee.fromJson(Map<String, dynamic> json) => CryptoFee(
        id: json['id'] as int,
        feeType: json['fee_type'] as String,
        flatUsd: double.tryParse(json['flat_usd'].toString()) ?? 0,
        percent: double.tryParse(json['percent'].toString()) ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );
}

// ── Service ───────────────────────────────────────────────────────────────────

class AdminService {
  static String _extractError(http.Response res) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final err = body['error'] ?? body['detail'];
      if (err is String) return err;
    } catch (_) {}
    return 'Something went wrong (${res.statusCode}).';
  }

  static Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on AdminException {
      rethrow;
    } on SocketException {
      throw AdminException('No internet connection.');
    } catch (e) {
      throw AdminException('Unexpected error: $e');
    }
  }

  // ── Admin profile ──────────────────────────────────────────────────────────

  static Future<AuthUser> getProfile() => _guard(() async {
        final headers = await AuthService.authHeaders();
        final res = await http.get(
          Uri.parse('$_kBaseUrl/admin/profile/'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
        }
        throw AdminException(_extractError(res));
      });

  static Future<AuthUser> updateProfile({
    String? fullName,
    String? phone,
  }) =>
      _guard(() async {
        final headers = await AuthService.authHeaders();
        final body = <String, dynamic>{
          'full_name': fullName,
          'phone': phone,
        }..removeWhere((_, v) => v == null);
        final res = await http.patch(
          Uri.parse('$_kBaseUrl/admin/profile/'),
          headers: headers,
          body: jsonEncode(body),
        );
        if (res.statusCode == 200) {
          final b = jsonDecode(res.body) as Map<String, dynamic>;
          return AuthUser.fromJson(b['user'] as Map<String, dynamic>);
        }
        throw AdminException(_extractError(res));
      });

  static Future<AuthUser> updateProfilePhoto(File photo) => _guard(() async {
        final authHeaders = await AuthService.authHeaders();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_kBaseUrl/auth/update-profile-photo/'),
        );
        request.headers['Authorization'] = authHeaders['Authorization']!;
        request.files
            .add(await http.MultipartFile.fromPath('profile_photo', photo.path));
        final streamed = await request.send();
        final res = await http.Response.fromStream(streamed);
        if (res.statusCode == 200) {
          final b = jsonDecode(res.body) as Map<String, dynamic>;
          return AuthUser.fromJson(b['user'] as Map<String, dynamic>);
        }
        throw AdminException(_extractError(res));
      });

  // ── Users ──────────────────────────────────────────────────────────────────

  static Future<AdminUsersResult> getUsers() => _guard(() async {
        final headers = await AuthService.authHeaders();
        final res = await http.get(
          Uri.parse('$_kBaseUrl/admin/users/'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return AdminUsersResult(
            total: (body['total'] as num?)?.toInt() ?? 0,
            active: (body['active'] as num?)?.toInt() ?? 0,
            blacklisted: (body['blacklisted'] as num?)?.toInt() ?? 0,
            users: (body['users'] as List<dynamic>)
                .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        }
        throw AdminException(_extractError(res));
      });

  /// Toggle a user's active/blacklisted state. Returns the new isActive value.
  static Future<bool> toggleBlacklist(String userId) => _guard(() async {
        final headers = await AuthService.authHeaders();
        final res = await http.post(
          Uri.parse('$_kBaseUrl/admin/users/$userId/'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return body['is_active'] as bool;
        }
        throw AdminException(_extractError(res));
      });

  // ── Fees ──────────────────────────────────────────────────────────────────

  static Future<List<CryptoFee>> getFees() => _guard(() async {
        final headers = await AuthService.authHeaders();
        final res = await http.get(
          Uri.parse('$_kBaseUrl/admin/fees/'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          return (body['fees'] as List<dynamic>)
              .map((e) => CryptoFee.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        throw AdminException(_extractError(res));
      });

  static Future<CryptoFee> updateFee(
    int feeId, {
    double? flatUsd,
    double? percent,
    bool? isActive,
  }) =>
      _guard(() async {
        final headers = await AuthService.authHeaders();
        final body = <String, dynamic>{
          'flat_usd': flatUsd?.toString(),
          'percent': percent?.toString(),
          'is_active': isActive,
        }..removeWhere((_, v) => v == null);
        final res = await http.patch(
          Uri.parse('$_kBaseUrl/admin/fees/$feeId/'),
          headers: headers,
          body: jsonEncode(body),
        );
        if (res.statusCode == 200) {
          return CryptoFee.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
        }
        throw AdminException(_extractError(res));
      });
}
