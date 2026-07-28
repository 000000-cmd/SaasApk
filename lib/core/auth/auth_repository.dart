import 'package:dio/dio.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Acceso a los endpoints de autenticación del gateway (`/auth`).
class AuthRepository {
  AuthRepository(this._client);
  final ApiClient _client;

  Future<LoginResult> login({required String email, required String password}) async {
    // El contrato del back es `usernameOrEmail` (igual que el front web).
    final Response<dynamic> res = await _client.dio.post<dynamic>(
      'auth/login',
      data: {'usernameOrEmail': email, 'password': password},
    );
    final Map<String, dynamic> data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return LoginResult.fromJson(data);
  }

  /// Apaga el indicador de primer ingreso del registro (app_user.IsFirstLogin):
  /// el tour de bienvenida no se vuelve a mostrar en ningún dispositivo.
  Future<void> markWelcomeSeen() =>
      _client.dio.patch<dynamic>('auth/users/me/welcome-seen');

  /// Registra en el back el consentimiento de huella del tercero vinculado a la
  /// cuenta: resuelve la persona por userId y hace PATCH del flag.
  Future<void> syncBiometric({required String userId, required bool enabled}) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('thirdparty/third-parties/by-user/$userId');
    final Map<String, dynamic>? person =
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    final String? thirdPartyId = person?['id'] as String?;
    if (thirdPartyId == null) return; // cuenta sin persona vinculada todavía
    await _client.dio.patch<dynamic>(
      'thirdparty/third-parties/$thirdPartyId/biometric',
      queryParameters: {'enabled': enabled},
    );
  }

}
