import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _client = http.Client();
  PersistCookieJar? _cookieJar;
  String? _token;
  bool _initialized = false;

  String? get token => _token;

  Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${dir.path}/.cookies/'),
    );
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(kTokenKey);
    _initialized = true;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
    await _cookieJar?.deleteAll();
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(kBaseUrl).replace(
      path: path,
      queryParameters: query,
    );
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (_token != null) headers['X-Session-Token'] = _token!;
    return headers;
  }

  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_cookieJar != null) {
      final cookies = await _cookieJar!.loadForRequest(request.url);
      if (cookies.isNotEmpty) {
        request.headers['Cookie'] = cookies.join('; ');
      }
    }
    if (_token != null) {
      request.headers['X-Session-Token'] = _token!;
    }
    final response = await _client.send(request);
    if (_cookieJar != null) {
      await _cookieJar!.saveFromResponse(
        request.url,
        response.headersSplitValues['set-cookie']
                ?.map((c) => Cookie.fromSetCookieValue(c))
                .toList() ??
            [],
      );
    }
    return response;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final response = await _client.get(
      _uri(path, query),
      headers: await _headers(),
    );
    return _handle(response);
  }

  Future<dynamic> post(String path,
      {Map<String, dynamic>? body, Map<String, dynamic>? query}) async {
    final response = await _client.post(
      _uri(path, query),
      headers: await _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client.delete(
      _uri(path),
      headers: await _headers(),
    );
    return _handle(response);
  }

  Future<dynamic> upload(String path, File file,
      {String field = 'file'}) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _headers(json: false));
    request.files.add(await http.MultipartFile.fromPath(field, file.path));
    final streamed = await send(request);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  dynamic _handle(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final isJson = contentType.contains('application/json');
    dynamic body;
    if (response.body.isNotEmpty && isJson) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    String message;
    if (body is Map) {
      message = body['detail'] ?? body['message'] ?? '请求失败';
    } else if (response.body.isNotEmpty) {
      message = response.body.length > 200
          ? '${response.body.substring(0, 200)}...'
          : response.body;
    } else {
      message = '请求失败 (HTTP ${response.statusCode})';
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Future<Map<String, String>> getSignatureInfo() async {
    try {
      const platform = MethodChannel(kSignatureChannel);
      final result = await platform.invokeMethod<Map<dynamic, dynamic>>('getSignature');
      return {
        'package_name': result?['packageName'] as String? ?? kPackageName,
        'signature_md5': result?['md5'] as String? ?? '',
      };
    } catch (e) {
      return {
        'package_name': kPackageName,
        'signature_md5': '',
      };
    }
  }
}
