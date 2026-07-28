import 'package:dio/dio.dart';
import 'package:saas_app/core/config/env.dart';
import 'package:saas_app/core/storage/token_storage.dart';

/// Cliente HTTP central (Dio). Interceptores: agrega `Bearer`, refresca el token
/// de forma transparente en 401 y reintenta, y limpia la sesión si el refresh
/// falla. Espeja la cadena de interceptores del front web.
class ApiClient {
  ApiClient({required TokenStorage storage, this.onSessionExpired}) : _storage = storage {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${Env.gatewayBaseUrl}/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final TokenStorage _storage;
  final void Function()? onSessionExpired;
  late final Dio _dio;
  bool _refreshing = false;

  Dio get dio => _dio;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final bool isPublic =
        options.path.startsWith('auth/login') || options.path.startsWith('auth/refresh');
    if (!isPublic) {
      final String? token = await _storage.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    final bool is401 = err.response?.statusCode == 401;
    final bool retried = err.requestOptions.extra['retried'] == true;
    final bool isRefreshCall = err.requestOptions.path.startsWith('auth/refresh');

    if (is401 && !retried && !isRefreshCall) {
      final bool ok = await _tryRefresh();
      if (ok) {
        try {
          final RequestOptions opts = err.requestOptions;
          opts.extra['retried'] = true;
          final String? token = await _storage.accessToken();
          if (token != null) opts.headers['Authorization'] = 'Bearer $token';
          final Response<dynamic> clone = await _dio.fetch<dynamic>(opts);
          return handler.resolve(clone);
        } catch (_) {
          // cae al handler de error de abajo
        }
      } else {
        await _storage.clear();
        onSessionExpired?.call();
      }
    }
    handler.next(err);
  }

  /// Refresca tokens. Ajustar el contrato (`refreshToken` / `accessToken`) si el
  /// back usa otros nombres en `/auth/refresh`.
  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final String? refresh = await _storage.refreshToken();
      if (refresh == null) return false;
      final Response<dynamic> res =
          await _dio.post<dynamic>('auth/refresh', data: {'refreshToken': refresh});
      final Map<String, dynamic>? data =
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      final String? access = data?['accessToken'] as String?;
      final String newRefresh = (data?['refreshToken'] as String?) ?? refresh;
      if (access == null) return false;
      await _storage.save(access: access, refresh: newRefresh);
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
