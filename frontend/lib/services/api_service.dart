// lib/services/api_service.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnUnauthorized = void Function();
OnUnauthorized? _onUnauthorized;

class ApiService {
  // TRUE singleton — one instance for the entire app lifetime
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _init();
  }

  late final Dio _dio;
  String? _cachedToken;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    webOptions: WebOptions(
        dbName: 'interview_prep_db', publicKey: 'interview_prep_key'),
  );

  static const String _productionUrl =
      'https://cheerful-flow-production-a98e.up.railway.app';

  static String get _baseUrl {
    if (kIsWeb) return _productionUrl;
    if (kReleaseMode) return _productionUrl;
    return 'http://10.0.2.2:8000';
  }

  static void setUnauthorizedCallback(OnUnauthorized cb) {
    _onUnauthorized = cb;
  }

  void _init() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
      // KEY FIX: follow redirects but keep headers (including Authorization)
      followRedirects: true,
      maxRedirects: 3,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Always read token — never rely on cache alone
        _cachedToken ??= await _storage.read(key: 'access_token');
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Only clear token if it's not a login/register request
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/google');
          if (!isAuthEndpoint) {
            _cachedToken = null;
            await _storage.delete(key: 'access_token');
            _onUnauthorized?.call();
          }
        }
        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: 'access_token', value: token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    await _storage.delete(key: 'access_token');
  }

  Future<bool> hasToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) return true;
    _cachedToken = await _storage.read(key: 'access_token');
    return _cachedToken != null && _cachedToken!.isNotEmpty;
  }

  // Force reload token from storage (call after login)
  Future<void> reloadToken() async {
    _cachedToken = await _storage.read(key: 'access_token');
  }

  Future<Response> get(String path,
          {Map<String, dynamic>? queryParameters}) async =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) async =>
      _dio.post(path, data: data, queryParameters: queryParameters);

  Future<Response> put(String path, {dynamic data}) async =>
      _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) async =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) async => _dio.delete(path);
}

// Returns the SAME singleton — not a new instance
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
