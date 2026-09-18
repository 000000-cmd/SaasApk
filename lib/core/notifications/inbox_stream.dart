import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';
import 'package:saas_app/core/notifications/device_notifier.dart';
import 'package:saas_app/core/notifications/inbox_repository.dart';

/// La bandeja EN VIVO, y lo que la convierte en un aviso del teléfono.
///
/// Mantiene una conexión abierta con el back (SSE) y recibe cada notificación
/// en el momento en que se escribe. Dos cosas pasan con lo que llega:
///   1. Se actualiza el contador de la app, sin recargar nada.
///   2. Se pinta en la bandeja del sistema, que es lo que la persona ve sin
///      tener la app delante.
///
/// ### Qué cubre esto y qué no
/// Con la app abierta o recién enviada al fondo, esto ES la notificación: llega
/// igual de rápido que una push y no depende de ningún servicio externo. Con la
/// app CERRADA del todo, Android no deja a nadie mantener una conexión abierta
/// —y hace bien, es lo que arruina la batería—, así que ahí hace falta FCM. El
/// back ya lo tiene montado; sólo le falta el proyecto de Firebase.
///
/// ### Por qué SSE y no un WebSocket
/// Todo lo que viaja va del servidor al teléfono. Marcar como leída es un PUT
/// normal. Un canal bidireccional con su broker sería el doble de piezas para
/// no usar la mitad, y en Dart además una librería más. SSE es HTTP corriente:
/// cruza el gateway y el túnel sin configurar nada.
class InboxStream {
  InboxStream(this._client, this._notifier);

  final ApiClient _client;
  final DeviceNotifier _notifier;

  final StreamController<InboxItem> _entrantes = StreamController<InboxItem>.broadcast();

  /// Lo que va llegando. Lo escucha quien quiera reaccionar (el contador, la
  /// lista abierta).
  Stream<InboxItem> get incoming => _entrantes.stream;

  CancelToken? _cancel;
  Timer? _reintento;
  Duration _espera = const Duration(seconds: 1);
  bool _parar = false;

  Future<void> start() async {
    if (_cancel != null) return;
    _parar = false;
    await _notifier.init();
    unawaited(_conectar());
  }

  void stop() {
    _parar = true;
    _reintento?.cancel();
    _reintento = null;
    _cancel?.cancel('stop');
    _cancel = null;
  }

  Future<void> _conectar() async {
    _cancel = CancelToken();
    try {
      final Response<ResponseBody> res = await _client.dio.get<ResponseBody>(
        'notification/stream',
        cancelToken: _cancel,
        options: Options(
          responseType: ResponseType.stream,
          headers: <String, String>{'Accept': 'text/event-stream'},
          // La conexión está callada a propósito entre aviso y aviso: sin esto
          // Dio la cortaría por inactividad a los 20 segundos.
          receiveTimeout: Duration.zero,
        ),
      );

      _espera = const Duration(seconds: 1);
      String buffer = '';

      await for (final List<int> trozo in res.data!.stream) {
        buffer += utf8.decode(trozo, allowMalformed: true);
        // Un evento SSE termina en línea en blanco. Se procesa lo completo y se
        // guarda el resto: un trozo puede cortar un evento por la mitad.
        int corte;
        while ((corte = buffer.indexOf('\n\n')) != -1) {
          _procesar(buffer.substring(0, corte));
          buffer = buffer.substring(corte + 2);
        }
      }
    } catch (_) {
      // Cortarla a propósito (logout, cierre) pasa por aquí igual: `_parar` es
      // lo que distingue "se cayó" de "la cerré yo".
    } finally {
      _cancel = null;
      if (!_parar) _programarReintento();
    }
  }

  /// Espera creciente hasta 30 s. Sin tope, una caída larga del back se
  /// convertiría en una tormenta de reconexiones justo cuando vuelve.
  void _programarReintento() {
    _reintento = Timer(_espera, () {
      _reintento = null;
      if (!_parar) unawaited(_conectar());
    });
    final int siguiente = _espera.inSeconds * 2;
    _espera = Duration(seconds: siguiente > 30 ? 30 : siguiente);
  }

  void _procesar(String bloque) {
    String evento = 'message';
    final List<String> datos = <String>[];
    for (final String linea in bloque.split('\n')) {
      if (linea.startsWith(':')) continue; // latido
      if (linea.startsWith('event:')) {
        evento = linea.substring(6).trim();
      } else if (linea.startsWith('data:')) {
        datos.add(linea.substring(5).trim());
      }
    }
    if (evento != 'inbox' || datos.isEmpty) return;

    try {
      final Map<String, dynamic> j = jsonDecode(datos.join('\n')) as Map<String, dynamic>;
      final InboxItem item = InboxItem.fromJson(j);
      _entrantes.add(item);
      unawaited(
        _notifier.show(
          title: item.title?.trim().isNotEmpty == true ? item.title! : 'Moda ERP',
          body: item.plainBody,
          payload: item.id,
        ),
      );
    } catch (_) {
      // Un evento ilegible no puede tumbar la conexión entera.
    }
  }

  void dispose() {
    stop();
    _entrantes.close();
  }
}

/// Vive mientras dure la sesión: arranca al entrar y se corta al salir.
final inboxStreamProvider = Provider<InboxStream>((ref) {
  final InboxStream s = InboxStream(
    ref.watch(apiClientProvider),
    ref.watch(deviceNotifierProvider),
  );
  ref.onDispose(s.dispose);

  // Se engancha al estado de sesión en vez de tener que arrancarlo a mano en
  // cada pantalla: así no hay forma de olvidarse de pararlo al cerrar sesión.
  ref.listen<AuthState>(
    authControllerProvider,
    (AuthState? antes, AuthState ahora) {
      if (ahora.isAuthenticated) {
        unawaited(s.start());
      } else {
        s.stop();
      }
    },
    fireImmediately: true,
  );

  return s;
});
