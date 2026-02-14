// lib/services/api_service.dart
// PERFORMANCE FIX: singleton + in-memory token cache
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _init();
  }

  late final Dio _dio;
  String? _cachedToken;

  static const _storage = FlutterSecureStorage(
      webOptions: WebOptions(
          dbName: 'interview_prep_db', publicKey: 'interview_prep_key'));

  void _init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 25),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        _cachedToken ??= await _storage.read(key: 'access_token');
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          _cachedToken = null;
          await _storage.delete(key: 'access_token');
        }
        return handler.next(error);
      },
    ));
  }

  // Expose raw Dio for advanced use (e.g. streaming downloads in resume_service)
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
    if (_cachedToken != null) return true;
    _cachedToken = await _storage.read(key: 'access_token');
    return _cachedToken != null && _cachedToken!.isNotEmpty;
  }

  Future<Response> get(String path,
          {Map<String, dynamic>? queryParameters}) async =>
      await _dio.get(path, queryParameters: queryParameters);

  Future<Response> post(String path,
          {dynamic data, Map<String, dynamic>? queryParameters}) async =>
      await _dio.post(path, data: data, queryParameters: queryParameters);

  Future<Response> put(String path, {dynamic data}) async =>
      await _dio.put(path, data: data);

  Future<Response> patch(String path, {dynamic data}) async =>
      await _dio.patch(path, data: data);

  Future<Response> delete(String path) async => await _dio.delete(path);
}
