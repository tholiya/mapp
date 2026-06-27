import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';

/// All session secrets live in the platform keystore — never SharedPreferences.
/// Keys mirror what React reads so token injection round-trips cleanly.
class SecureStore {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';
  static const _kPerms = 'auth_permissions';
  static const _kBiometric = 'biometric_enabled';

  final FlutterSecureStorage _s;

  SecureStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> saveSession({
    required String token,
    required AuthUser user,
    required List<String> permissionKeys,
  }) async {
    await _s.write(key: _kToken, value: token);
    await _s.write(key: _kUser, value: user.encode());
    await _s.write(key: _kPerms, value: jsonEncode(permissionKeys));
  }

  Future<String?> readToken() => _s.read(key: _kToken);

  Future<String?> readUserJson() => _s.read(key: _kUser);

  Future<AuthUser?> readUser() async {
    final raw = await _s.read(key: _kUser);
    if (raw == null) return null;
    try {
      return AuthUser.decode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Raw JSON string for the permissions array — used directly by the injector.
  Future<String> readPermissionsJson() async =>
      (await _s.read(key: _kPerms)) ?? '[]';

  Future<bool> hasSession() async => (await readToken()) != null;

  // Biometric app-unlock preference --------------------------------------------
  Future<bool> isBiometricEnabled() async =>
      (await _s.read(key: _kBiometric)) == 'true';

  Future<void> setBiometricEnabled(bool v) =>
      _s.write(key: _kBiometric, value: v ? 'true' : 'false');

  /// Wipe everything on logout. Keeps no residual session material.
  Future<void> clear() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kUser);
    await _s.delete(key: _kPerms);
    await _s.delete(key: _kBiometric);
  }
}
