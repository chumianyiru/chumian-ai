import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/constants.dart';
import 'api_client.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(kUserKey);
    if (json != null) {
      _currentUser = User.fromJson(jsonDecode(json));
    }
  }

  Future<void> _saveUser(User user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kUserKey, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kUserKey);
  }

  Future<void> verifyClient() async {
    final info = await ApiClient.getSignatureInfo();
    await ApiClient().post('/api/auth/client/verify', body: info);
  }

  Future<bool> verifyClientMatches() async {
    final info = await ApiClient.getSignatureInfo();
    final md5 = info['signature_md5']?.toUpperCase().replaceAll(':', '') ?? '';
    return md5 == kExpectedSignatureMd5 || md5 == kIosPlaceholderMd5;
  }

  Future<void> sendCode(String email) async {
    await ApiClient().post('/api/auth/send-code', body: {'email': email});
  }

  Future<User> register({
    required String email,
    required String code,
    required String password,
    required String nickname,
  }) async {
    final res = await ApiClient().post('/api/auth/register', body: {
      'email': email,
      'code': code,
      'password': password,
      'nickname': nickname,
    });
    final token = res['token'] as String;
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    await ApiClient().setToken(token);
    await _saveUser(user);
    return user;
  }

  Future<User> login(String email, String password) async {
    final info = await ApiClient.getSignatureInfo();
    final res = await ApiClient().post('/api/auth/login', body: {
      'email': email,
      'password': password,
      'package_name': info['package_name'],
      'signature_md5': info['signature_md5'],
    });
    final token = res['token'] as String;
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    await ApiClient().setToken(token);
    await _saveUser(user);
    return user;
  }

  Future<User> fetchMe() async {
    final res = await ApiClient().get('/api/auth/me');
    final user = User.fromJson(res as Map<String, dynamic>);
    await _saveUser(user);
    return user;
  }

  Future<User> completeOobe() async {
    final res = await ApiClient().post('/api/auth/oobe-complete');
    final user = User.fromJson(res as Map<String, dynamic>);
    await _saveUser(user);
    return user;
  }

  Future<void> logout() async {
    try {
      await ApiClient().post('/api/auth/logout');
    } finally {
      await ApiClient().clearToken();
      await clearUser();
    }
  }
}
