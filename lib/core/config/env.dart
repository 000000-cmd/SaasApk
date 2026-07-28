/// Configuración de entorno. El APK consume el MISMO gateway que la web.
class Env {
  Env._();

  /// Base del gateway. En el emulador Android, `10.0.2.2` mapea al `localhost`
  /// del host. Sobre-escribir con `--dart-define=GATEWAY_URL=...` en build/run.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
}

/// Prefijos de microservicio (igual que en el front web). Componer rutas con [ms].
class Ms {
  Ms._();
  static const String auth = 'auth';
  static const String system = 'system';
  static const String business = 'business';
  static const String thirdparty = 'thirdparty';
  static const String search = 'search';
  static const String audit = 'audit';
}

/// `ms(Ms.auth, 'login')` -> `auth/login`.
String ms(String prefix, String path) => '$prefix/${path.replaceFirst(RegExp(r'^/'), '')}';
