/// Configuración de entorno. El APK consume el MISMO gateway que la web.
class Env {
  Env._();

  /// Base del gateway.
  ///
  /// El valor por defecto es el DOMINIO PÚBLICO, no el emulador. Un APK
  /// instalado en un teléfono real nunca puede alcanzar `10.0.2.2` —esa
  /// dirección solo existe dentro del emulador de Android— así que dejarla de
  /// defecto significaba que cualquier build que saliera de esta máquina no
  /// conectaba con nada y moría en "revisa tu conexión".
  ///
  /// Para desarrollo contra el backend local, sobre-escribir en el build:
  ///
  ///   flutter run --dart-define=GATEWAY_URL=http://10.0.2.2:8080
  ///
  /// El túnel de Cloudflare publica este mismo gateway; ver
  /// `SaasBack/deploy/cloudflared/README.md`.
  static const String gatewayBaseUrl = String.fromEnvironment(
    'GATEWAY_URL',
    defaultValue: 'https://back.sylvanor.lat',
  );

  /// Si el gateway se alcanza por HTTP plano (desarrollo local). Android bloquea
  /// el tráfico sin cifrar salvo en los hosts declarados en
  /// `network_security_config.xml`.
  static bool get isCleartext => gatewayBaseUrl.startsWith('http://');
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
