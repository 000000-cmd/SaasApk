import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Una notificación tal y como la ve quien la recibe.
///
/// Sale de `notification_inbox`, que el backend escribe en TODO envío salga por
/// donde salga — correo, WhatsApp, mensaje de texto o notificación al teléfono.
/// Por eso esta lista y la campana de la web muestran exactamente lo mismo: no
/// son dos historiales que puedan discrepar, es la misma tabla.
class InboxItem {
  final String id;
  final String? title;
  final String body;
  final String? typeCode;
  final DateTime? readAt;
  final DateTime createdDate;

  const InboxItem({
    required this.id,
    required this.body,
    required this.createdDate,
    this.title,
    this.typeCode,
    this.readAt,
  });

  bool get unread => readAt == null;

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'].toString(),
        title: j['title']?.toString(),
        body: (j['body'] ?? '').toString(),
        typeCode: j['typeCode']?.toString(),
        readAt: _date(j['readAt']),
        createdDate: _date(j['createdDate']) ?? DateTime.now(),
      );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  /// El cuerpo puede venir con HTML (una plantilla de correo). En el teléfono se
  /// muestra como texto: pintar marcado ajeno no aporta nada y sí puede romper
  /// el diseño de la lista.
  String get plainBody => body
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class InboxRepository {
  InboxRepository(this._client);
  final ApiClient _client;

  /// Bandeja del usuario en sesión. El backend resuelve a qué tercero pertenece
  /// la cuenta, así que aquí no hace falta saber nada de eso.
  Future<List<InboxItem>> mine({int page = 0, int size = 30}) async {
    final Response<dynamic> res = await _client.dio.get<dynamic>(
      'notification/inbox/me',
      queryParameters: <String, dynamic>{'page': page, 'size': size},
    );
    final Map<String, dynamic>? data =
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    final List<dynamic> content = (data?['content'] as List?) ?? const [];
    return content
        .map((e) => InboxItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('notification/inbox/me/unread-count');
    final Map<String, dynamic>? data =
        (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    return ((data?['count'] ?? 0) as num).toInt();
  }

  Future<void> markRead(String id) =>
      _client.dio.put<dynamic>('notification/inbox/$id/read');

  Future<void> markAllRead() =>
      _client.dio.put<dynamic>('notification/inbox/me/read-all');

  /// Registra este teléfono para recibir notificaciones push.
  ///
  /// Todavía no se llama: hace falta el proyecto de Firebase y el paquete
  /// `firebase_messaging` para obtener un token real. El endpoint ya existe y
  /// reasigna el token si el aparato cambia de dueño, así que cuando llegue esa
  /// pieza sólo hay que invocar esto al arrancar con el token de FCM.
  Future<void> registerDevice({
    required String thirdPartyId,
    required String fcmToken,
    required String platform,
    String? appVersion,
  }) =>
      _client.dio.post<dynamic>(
        'notification/devices',
        data: <String, dynamic>{
          'thirdPartyId': thirdPartyId,
          'fcmToken': fcmToken,
          'platform': platform,
          'appVersion': appVersion,
        },
      );
}

final inboxRepositoryProvider =
    Provider<InboxRepository>(
  (ref) => InboxRepository(ref.watch(apiClientProvider)),
);

/// Contador de no leídas. Lo pinta la campana del panel.
///
/// Se refresca al entrar y al salir de la bandeja; no hay sondeo, igual que en
/// la web: para que el número se mueva solo hace falta un canal en vivo, y
/// montarlo por un contador no compensa.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return await ref.watch(inboxRepositoryProvider).unreadCount();
  } catch (_) {
    // Sin red o sin tercero asociado: cero, nunca una pantalla rota.
    return 0;
  }
});
