import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/api_exception.dart';
import '../models/auth_user.dart';
import 'secure_store.dart';

/// Result of a successful native login — everything React needs seeded.
class LoginResult {
  final String token;
  final AuthUser user;
  final List<String> permissionKeys;
  const LoginResult(this.token, this.user, this.permissionKeys);
}

/// Native auth against user-service. Mirrors react/lib/api.ts request handling:
/// every response is the `{ success, message, data, error, errors }` envelope;
/// non-success throws an [ApiException] carrying field-level errors.
class AuthService {
  final Dio _dio;
  final SecureStore _store;

  AuthService(this._store, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.userServiceUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              // We unwrap the envelope ourselves, so accept any status code.
              validateStatus: (_) => true,
              headers: {'Content-Type': 'application/json'},
            ));

  static const _loginPath = '/user/api/v1/users/login';
  static const _logoutPath = '/user/api/v1/users/logout';

  Future<LoginResult> login(String email, String password) async {
    late Response res;
    try {
      res = await _dio.post(_loginPath, data: {
        'email': email.trim(),
        'password': password,
      });
    } on DioException {
      throw const ApiException(
        'NETWORK_ERROR',
        'Cannot reach server. Check your connection.',
      );
    }

    final body = _asMap(res.data);
    final success = body['success'] == true;

    if (!success) {
      throw _toApiException(body, res.statusCode ?? 0);
    }

    final data = _asMap(body['data']);
    final token = data['token'] as String?;
    if (token == null) {
      throw const ApiException('PARSE_ERROR', 'Malformed login response.');
    }
    final user = AuthUser.fromJson(_asMap(data['user']));
    final perms = (data['permissionKeys'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    await _store.saveSession(token: token, user: user, permissionKeys: perms);
    return LoginResult(token, user, perms);
  }

  /// Best-effort server logout (mirrors AuthContext.logout). Local wipe is the
  /// caller's responsibility and happens regardless.
  Future<void> serverLogout() async {
    final token = await _store.readToken();
    if (token == null) return;
    try {
      await _dio.post(
        _logoutPath,
        data: const {},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Best-effort — ignore failures, we clear locally anyway.
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : <String, dynamic>{};

  ApiException _toApiException(Map<String, dynamic> body, int status) {
    final error = _asMap(body['error']);
    final errors = (body['errors'] as List?) ?? const [];
    return ApiException(
      (error['code'] as String?) ?? 'API_ERROR',
      (body['message'] as String?) ?? 'An error occurred',
      status: status,
      validationErrors: errors
          .whereType<Map>()
          .map((e) => FieldValidationError(
                e['field']?.toString() ?? '',
                e['message']?.toString() ?? '',
              ))
          .toList(),
    );
  }
}
