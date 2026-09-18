import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistencia segura de la sesión (Keychain en iOS / Keystore en Android).
/// Guardamos también el usuario serializado para restaurar la sesión sin pegarle
/// al back en el arranque.
class TokenStorage {
  const TokenStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _kAccess = 'access_token';
  static const String _kRefresh = 'refresh_token';
  static const String _kUser = 'auth_user';
  static const String _kOnboard = 'onboarding_done_'; // + userId
  static const String _kBioEnabled = 'biometric_enabled_'; // + userId
  static const String _kBioPrompted = 'biometric_prompted_'; // + userId
  static const String _kDeviceFallback = 'device_fallback_id';
  // El tour de bienvenida ya NO se marca en el dispositivo: lo gobierna el
  // indicador IsFirstLogin del registro del usuario (ver AuthController).

  Future<void> save({
    required String access,
    required String refresh,
    String? userJson,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    if (userJson != null) {
      await _storage.write(key: _kUser, value: userJson);
    }
  }

  Future<String?> accessToken() => _storage.read(key: _kAccess);
  Future<String?> refreshToken() => _storage.read(key: _kRefresh);
  Future<String?> userJson() => _storage.read(key: _kUser);

  /// Onboarding de primer ingreso del empleado (persiste por usuario; NO se
   /// borra al cerrar sesión: es de una sola vez). Migrará a un flag del back.
  Future<bool> isOnboardingDone(String userId) async =>
      (await _storage.read(key: '$_kOnboard$userId')) == 'true';

  Future<void> setOnboardingDone(String userId) =>
      _storage.write(key: '$_kOnboard$userId', value: 'true');

  /// Actualiza solo el usuario de la sesión (sin tocar los tokens).
  Future<void> saveUser(String userJson) => _storage.write(key: _kUser, value: userJson);

  // ---- Huella (por usuario; sobrevive al logout, igual que el onboarding) ----

  Future<bool> isBiometricEnabled(String userId) async =>
      (await _storage.read(key: '$_kBioEnabled$userId')) == 'true';

  Future<void> setBiometricEnabled(String userId, bool enabled) =>
      _storage.write(key: '$_kBioEnabled$userId', value: enabled ? 'true' : 'false');

  /// Ya se le ofreció habilitar la huella (para no insistir en cada login).
  Future<bool> wasBiometricPrompted(String userId) async =>
      (await _storage.read(key: '$_kBioPrompted$userId')) == 'true';

  Future<void> setBiometricPrompted(String userId) =>
      _storage.write(key: '$_kBioPrompted$userId', value: 'true');

  // ---- Identidad del aparato ----
  //
  // Respaldo del identificador de dispositivo, para cuando Android no da el
  // suyo. NO se borra al cerrar sesión: es del teléfono, no de la cuenta —
  // borrarlo haría que el mismo aparato pareciera otro en el siguiente login.

  Future<String?> deviceFallbackId() => _storage.read(key: _kDeviceFallback);

  Future<void> setDeviceFallbackId(String value) =>
      _storage.write(key: _kDeviceFallback, value: value);

  Future<void> clear() async {
    // Sólo la sesión; el flag de onboarding por usuario se conserva.
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}
