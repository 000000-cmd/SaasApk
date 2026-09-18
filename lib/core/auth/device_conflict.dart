import 'package:dio/dio.dart';

/// La contraseña era correcta, pero hay una sesión abierta en otro sitio.
///
/// No es un fallo de credenciales y la pantalla no debe tratarlo como tal: lo
/// que toca es preguntar, no decir "no se pudo entrar". Por eso llega con el
/// detalle de qué aparato es y desde cuándo — sin eso, "tu cuenta está abierta
/// en otro dispositivo" no le dice a nadie si es su teléfono viejo o alguien más.
class DeviceConflict implements Exception {
  const DeviceConflict({required this.message, required this.items});

  final String message;
  final List<ConflictItem> items;

  /// ¿Hay que avisar de que este teléfono tiene otra cuenta abierta?
  bool get hasOtherAccount => items.any((ConflictItem i) => i.kind == ConflictItem.otherAccount);

  /// ¿Hay que avisar de que esta cuenta está abierta en otro teléfono?
  bool get hasOtherDevice => items.any((ConflictItem i) => i.kind == ConflictItem.otherDevice);

  /// Qué se le va a cerrar si acepta. Es lo que va en el botón de confirmar.
  String get consequence {
    if (hasOtherDevice && hasOtherAccount) {
      return 'Se cerrará tu sesión en el otro dispositivo y la otra cuenta de este teléfono.';
    }
    if (hasOtherDevice) {
      final ConflictItem i = items.firstWhere((ConflictItem x) => x.kind == ConflictItem.otherDevice);
      return 'Se cerrará tu sesión en ${i.deviceName}.';
    }
    final ConflictItem i = items.firstWhere((ConflictItem x) => x.kind == ConflictItem.otherAccount);
    return 'Se cerrará la sesión de ${i.account} en este teléfono.';
  }

  /// Reconoce el 409 del back. Devuelve null si la respuesta es otra cosa, para
  /// que el error original siga su camino sin disfrazarse.
  static DeviceConflict? tryParse(DioException e) {
    if (e.response?.statusCode != 409) return null;
    final dynamic cuerpo = e.response?.data;
    if (cuerpo is! Map) return null;
    final dynamic data = cuerpo['data'];
    if (data is! Map || data['conflicts'] is! List) return null;

    return DeviceConflict(
      message: (cuerpo['message'] ?? 'Tu cuenta ya está abierta en otro dispositivo.') as String,
      items: (data['conflicts'] as List<dynamic>)
          .whereType<Map<dynamic, dynamic>>()
          .map(ConflictItem.fromJson)
          .toList(),
    );
  }

  @override
  String toString() => message;
}

class ConflictItem {
  const ConflictItem({
    required this.kind,
    required this.deviceName,
    required this.account,
    required this.lastSeenAt,
  });

  static const String otherDevice = 'OTHER_DEVICE';
  static const String otherAccount = 'OTHER_ACCOUNT';

  final String kind;
  final String deviceName;

  /// En OTHER_ACCOUNT llega parcialmente oculta ("an***s"): quien intenta entrar
  /// tiene derecho a saber que el teléfono tiene otra cuenta, no cuál.
  final String account;
  final DateTime? lastSeenAt;

  factory ConflictItem.fromJson(Map<dynamic, dynamic> j) => ConflictItem(
        kind: (j['kind'] ?? '') as String,
        deviceName: (j['deviceName'] ?? 'Otro dispositivo') as String,
        account: (j['account'] ?? 'otra cuenta') as String,
        lastSeenAt: DateTime.tryParse((j['lastSeenAt'] ?? '') as String),
      );

  /// "hace 3 días" dice más que una fecha completa cuando hay que decidir.
  String get relative {
    if (lastSeenAt == null) return '';
    final Duration d = DateTime.now().difference(lastSeenAt!);
    if (d.inMinutes < 1) return 'ahora mismo';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    return 'hace ${d.inDays} días';
  }
}
