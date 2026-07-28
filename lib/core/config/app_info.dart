/// Identidad de la build. [version] se compara contra la versión vigente
/// publicada por el admin (/system/public/app-versions/latest): si difieren,
/// el APK exige actualizar (y puede descargar/instalar desde el mismo modal).
/// Al publicar, el back sincroniza también la constante VERAPP.
class AppInfo {
  AppInfo._();

  /// OJO: tiene que ir a la par de `version:` en pubspec.yaml. Esta es la que
  /// compara el gate contra la constante VERAPP; la del pubspec es la que ve
  /// Android. Si se tocan por separado, el APK se bloquea a sí mismo.
  static const String version = '1.0.3';

  /// Nombre de marca que se muestra en la app (login, encabezados).
  static const String appName = 'Luminous Aura';
}
