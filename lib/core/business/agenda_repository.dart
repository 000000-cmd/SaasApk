/// La AGENDA del empleado: sus citas, tal como las guarda el negocio.
///
/// Es la mitad del trabajo que todavía no es dinero. El dinero —la comisión, el
/// saldo, lo consignado— vive en `service_charge_repository` y en
/// `settlement_repository`, y viene de otro servicio.
///
/// Que sean dos fuentes no es un descuido de diseño: la cita la manda la
/// agenda del negocio y el cargo lo manda finance. Cuando el APK marcaba
/// terminado el CARGO, la cita se quedaba confirmada y el panel del dueño y la
/// app contaban cosas distintas del mismo servicio. Ahora se mueve la cita, que
/// es donde consta que el servicio se prestó, y el cargo la sigue.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Una cita del empleado. Los importes son los del SNAPSHOT: lo que costaba el
/// servicio cuando se agendó, no lo que cuesta hoy.
class AgendaAppointment {
  final String id;
  final String publicCode;
  final String employeeId;

  /// `PENDIENTE_CONFIRMACION`, `CONFIRMADA`, `EN_CURSO`, `COMPLETADA`,
  /// `CANCELADA_CLIENTE`, `CANCELADA_NEGOCIO`, `NO_ASISTIO`, `EXPIRADA`.
  final String status;

  /// Por dónde entró: `WEB_PUBLICA`, `PANEL_DUENO`, `APK_EMPLEADO`, `WHATSAPP`.
  final String channel;

  final DateTime startUtc;
  final DateTime endUtc;
  final DateTime localDate;
  final bool backdated;

  final double totalPrice;
  final int totalMinutes;
  final String serviceName;
  final String clientName;
  final String? clientPhone;
  final String? notes;

  const AgendaAppointment({
    required this.id,
    required this.publicCode,
    required this.employeeId,
    required this.status,
    required this.channel,
    required this.startUtc,
    required this.endUtc,
    required this.localDate,
    required this.backdated,
    required this.totalPrice,
    required this.totalMinutes,
    required this.serviceName,
    required this.clientName,
    this.clientPhone,
    this.notes,
  });

  factory AgendaAppointment.fromJson(Map<String, dynamic> j) {
    final DateTime inicio =
        DateTime.tryParse((j['startUtc'] ?? '').toString())?.toLocal() ?? DateTime.now();
    return AgendaAppointment(
      id: j['id'].toString(),
      publicCode: (j['publicCode'] ?? '').toString(),
      employeeId: (j['employeeId'] ?? '').toString(),
      status: (j['status'] ?? 'CONFIRMADA').toString(),
      channel: (j['channel'] ?? '').toString(),
      startUtc: inicio,
      endUtc: DateTime.tryParse((j['endUtc'] ?? '').toString())?.toLocal() ?? inicio,
      localDate: DateTime.tryParse((j['localDate'] ?? '').toString()) ?? inicio,
      backdated: j['backdated'] == true,
      totalPrice: _num(j['totalPrice']),
      totalMinutes: (j['totalMinutes'] as num?)?.toInt() ?? 0,
      serviceName: (j['serviceName'] ?? 'Servicio').toString(),
      clientName: (j['clientName'] ?? 'Cliente').toString(),
      clientPhone: j['clientPhone'] as String?,
      notes: j['notes'] as String?,
    );
  }

  static double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();
}

class AgendaRepository {
  AgendaRepository(this._client);
  final ApiClient _client;

  /// Las citas del empleado en una ventana de días.
  ///
  /// El servidor comprueba que ese registro laboral sea de quien pregunta: sin
  /// eso, cambiar el id en la petición mostraría la agenda de un compañero —a
  /// quién atiende, a qué hora y con qué teléfono—, porque el aislamiento por
  /// negocio no separa a dos personas del MISMO negocio.
  Future<List<AgendaAppointment>> ofEmployee(
    String employeeId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final Response<dynamic> res = await _client.dio.get<dynamic>(
      'business/appointments/employee/$employeeId',
      queryParameters: <String, dynamic>{'from': _dia(from), 'to': _dia(to)},
    );
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => AgendaAppointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Mueve la cita. Desde la app solo caben `EN_CURSO` y `COMPLETADA`: cancelar
  /// o marcar inasistencia decide si a alguien se le cobra, y eso es del dueño.
  Future<void> changeStatus(String appointmentId, String status) async {
    await _client.dio.post<dynamic>(
      'business/appointments/$appointmentId/status',
      data: <String, dynamic>{'status': status, 'reason': null},
    );
  }

  /// Le pide a finance que cree los cargos de las citas que aún no lo tienen.
  ///
  /// Se llama al cargar la pantalla y después de terminar un servicio, para que
  /// el empleado vea su comisión sin esperar a que el dueño abra el panel. Es
  /// idempotente: repetirlo no le paga nada de más a nadie.
  Future<void> syncCharges(String businessId) async {
    await _client.dio.post<dynamic>(
      'finance/service-charges/sync',
      queryParameters: <String, dynamic>{'businessId': businessId},
    );
  }

  static String _dia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final agendaRepositoryProvider =
    Provider<AgendaRepository>((ref) => AgendaRepository(ref.watch(apiClientProvider)));
