import 'package:dio/dio.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/auth/device_conflict.dart';
import 'package:saas_app/core/auth/device_identity.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Acceso a los endpoints de autenticación del gateway (`/auth`).
class AuthRepository {
  AuthRepository(this._client, this._device);
  final ApiClient _client;
  final DeviceIdentity _device;

  /// Entra.
  ///
  /// Va acompañado de la identidad del aparato, que es lo que permite al back
  /// aplicar la regla de "una cuenta, un dispositivo". Si hay una sesión abierta
  /// en otro sitio, el back responde 409 con el detalle: eso NO es un error de
  /// credenciales y no se trata como tal — se convierte en
  /// [DeviceConflict] para que la pantalla pueda preguntar.
  ///
  /// [unlinkOthers] es el reintento, después de que la persona haya dicho que sí.
  Future<LoginResult> login({
    required String email,
    required String password,
    bool unlinkOthers = false,
  }) async {
    try {
      final Response<dynamic> res = await _client.dio.post<dynamic>(
        'auth/login',
        data: <String, dynamic>{
          'usernameOrEmail': email,
          'password': password,
          'device': await _device.payload(),
          'unlinkOthers': unlinkOthers,
        },
      );
      final Map<String, dynamic> data =
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return LoginResult.fromJson(data);
    } on DioException catch (e) {
      final DeviceConflict? choque = DeviceConflict.tryParse(e);
      if (choque != null) throw choque;
      rethrow;
    }
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
