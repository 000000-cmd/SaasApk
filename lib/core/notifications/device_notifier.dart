
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// La notificación de la BANDEJA DEL TELÉFONO (la que suena y aparece arriba).
///
/// No confundir con la bandeja de la app: esa es una lista dentro del programa.
/// Esto es lo que ve la persona sin abrir nada.
///
/// ### El canal
/// Android agrupa las notificaciones por canal, y el canal es lo que permite a
/// la persona silenciar unas cosas y otras no desde los ajustes del sistema.
/// El identificador tiene que ser EL MISMO que manda el back en el bloque
/// `android.notification.channel_id`; si no coincide, Android las entrega en el
/// canal por defecto y esa configuración deja de existir.
class DeviceNotifier {
  DeviceNotifier();

  /// Debe coincidir con `FcmClient.CANAL_ANDROID` del back.
  static const String canalId = 'moda_erp_avisos';
  static const String canalNombre = 'Avisos de Moda ERP';
  static const String canalDescripcion =
      'Pagos, liquidaciones y mensajes del negocio.';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  /// Contador propio: dos notificaciones con el mismo id se pisan, y perder un
  /// aviso porque llegó otro detrás es peor que acumular dos líneas.
  int _siguienteId = 0;

  Future<void> init() async {
    if (_listo) return;

    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );

    // El canal se crea explícitamente y no se deja a la primera notificación:
    // así aparece en los ajustes del sistema desde el primer arranque y se
    // puede configurar antes de haber recibido nada.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        canalId,
        canalNombre,
        description: canalDescripcion,
        importance: Importance.high,
      ),
    );
    _listo = true;
  }

  /// Pide el permiso de notificaciones (Android 13+).
  ///
  /// Se pide cuando ya hay sesión, no al instalar: un permiso que se pregunta
  /// antes de que la app haya demostrado para qué lo quiere se deniega, y en
  /// Android denegar dos veces lo bloquea para siempre.
  Future<bool> requestPermission() async {
    await init();
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<bool> enabled() async {
    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? false;
  }

  /// Pinta una notificación en la bandeja del sistema.
  Future<void> show({required String title, required String body, String? payload}) async {
    await init();
    await _plugin.show(
      id: _siguienteId++,
      title: title,
      body: body,
      payload: payload,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          canalId,
          canalNombre,
          channelDescription: canalDescripcion,
          importance: Importance.high,
          priority: Priority.high,
          // Texto largo desplegable: el cuerpo de una liquidación no cabe en
          // una línea y cortarlo deja el dato importante fuera.
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

final deviceNotifierProvider = Provider<DeviceNotifier>((_) => DeviceNotifier());
