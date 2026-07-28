import 'package:local_auth/local_auth.dart';

/// Acceso a la biometría del dispositivo (huella/rostro). La validación ocurre
/// 100% en el equipo: al back solo viaja el consentimiento (BiometricEnabled).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// True si el equipo tiene hardware biométrico utilizable.
  /// Catch amplio: en plataformas sin implementación (p. ej. web) el canal
  /// lanza MissingPluginException, no PlatformException.
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Lanza el prompt del sistema. Devuelve true si la huella fue validada.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
