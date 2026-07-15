import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUser = 'auth_user_json';

  static final _storage = FlutterSecureStorage();

  Future<void> save({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveUserJson(String userJson) async {
    await _storage.write(key: _kUser, value: userJson);
  }

  Future<String?> getUserJson() async {
    return await _storage.read(key: _kUser);
  }

  Future<String?> getAccess() async {
    return await _storage.read(key: _kAccess);
  }

  Future<String?> getRefresh() async {
    return await _storage.read(key: _kRefresh);
  }

  Future<bool> hasToken() async {
    final access = await _storage.read(key: _kAccess);
    return access != null && access.isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}