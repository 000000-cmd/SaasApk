/// El TRABAJO del empleado: la agenda y lo ya prestado.
///
/// Cada servicio tiene DOS dueños y aquí se juntan:
///
///   * la **cita** la manda la agenda del negocio (business) — cuándo, con
///     quién, y si ya empezó o terminó;
///   * el **cargo** lo manda finance — cuánto se lleva él y si ya se aprobó.
///
/// Se unen por `appointmentId`. Antes esta pantalla leía SOLO cargos y trataba
/// la cita y el cargo como la misma fila; con el módulo de citas dentro eso
/// dejó de ser cierto: el APK marcaba terminado el cargo, la cita se quedaba
/// confirmada, y el panel del dueño y la app contaban cosas distintas del mismo
/// servicio.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/business/agenda_repository.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Dónde está un servicio dentro de su ciclo, ya resuelto para la pantalla.
///
/// No es el estado del back uno a uno: [hoy] y [agendado] son la misma cita
/// confirmada leída con el calendario delante, porque para quien abre la app
/// una cita de hoy y una de la semana que viene son cosas muy distintas —
/// sobre una actúa y sobre la otra no.
enum ServicePhase {
  /// Reservada por el cliente; el negocio todavía no la ha aceptado.
  porConfirmar,

  /// Aceptada, para otro día. Se ve, no se toca.
  agendado,

  /// Aceptada y es HOY. Aquí empieza lo que el empleado puede hacer.
  hoy,

  /// La empezó. Falta darla por terminada.
  enCurso,

  /// La terminó; espera que el dueño la apruebe.
  porAprobar,

  /// Aprobada, entra en la próxima liquidación (todavía no está en el saldo).
  aprobado,

  /// Aprobada Y liquidada: ya sumó al saldo y se pagará en nómina.
  abonado,

  /// El dueño no la aprobó. No se paga, pero no desaparece.
  rechazado,

  /// No se prestó: cancelada, o el cliente no llegó.
  cancelado;

  bool get esAgenda =>
      this == porConfirmar || this == agendado || this == hoy || this == enCurso;

  /// Ya no se puede tocar: o está en manos del dueño, o ya se contó.
  bool get esCerrado => this == abonado || this == rechazado || this == cancelado;
}

/// Un servicio del empleado: la cita y su cargo, si ya existe.
class ServiceItem {
  /// La cita en la agenda. Nulo solo para un cargo sin cita detrás.
  final String? appointmentId;

  /// El cargo en finance. Nulo mientras la sincronización no lo haya creado.
  final String? chargeId;

  /// Estado de la CITA (`CONFIRMADA`, `EN_CURSO`, `COMPLETADA`, …).
  final String? appointmentStatus;

  /// Estado del CARGO (`SCHEDULED`, `PENDING`, `CONFIRMED`, `DISCARDED`).
  final String? chargeStatus;

  final String serviceName;
  final DateTime serviceDate;
  final String? startTime;
  final String? endTime;

  final String clientName;
  final String? clientEmail;
  final String? clientPhone;

  /// Lo que paga el cliente y lo que le queda a él. La diferencia es del negocio.
  final double grossAmount;
  final double deductionRate;
  final double netAmount;

  final String paymentMethod;
  final String? settlementId;
  final String? discardReason;
  final String? resultPhotoUrl;

  const ServiceItem({
    required this.serviceName,
    required this.serviceDate,
    required this.clientName,
    required this.grossAmount,
    required this.deductionRate,
    required this.netAmount,
    required this.paymentMethod,
    this.appointmentId,
    this.chargeId,
    this.appointmentStatus,
    this.chargeStatus,
    this.startTime,
    this.endTime,
    this.clientEmail,
    this.clientPhone,
    this.settlementId,
    this.discardReason,
    this.resultPhotoUrl,
  });

  /// La llave de la fila: la cita si la hay, y si no el cargo.
  String get id => appointmentId ?? chargeId ?? '';

  /// Ya hay cargo, así que la comisión está calculada y se puede enseñar.
  bool get tieneCargo => chargeId != null;

  /// Lo que se enseña en grande. Mientras no haya cargo no se sabe la comisión,
  /// y poner un cero donde va la parte de alguien es peor que poner el precio.
  double get montoVisible => tieneCargo ? netAmount : grossAmount;

  /// La fase, mirando primero la cita y después el dinero.
  ///
  /// El ORDEN importa: una cita cancelada también descarta su cargo, y si se
  /// mirara el cargo primero se leería "tu jefe no lo aprobó" cuando lo que
  /// pasó es que el cliente no vino.
  ServicePhase get phase {
    switch (appointmentStatus) {
      case 'CANCELADA_CLIENTE':
      case 'CANCELADA_NEGOCIO':
      case 'NO_ASISTIO':
      case 'EXPIRADA':
        return ServicePhase.cancelado;
      case 'PENDIENTE_CONFIRMACION':
        return ServicePhase.porConfirmar;
      case 'EN_CURSO':
        return ServicePhase.enCurso;
    }

    if (chargeStatus == 'DISCARDED') return ServicePhase.rechazado;
    if (chargeStatus == 'CONFIRMED') {
      return settlementId == null ? ServicePhase.aprobado : ServicePhase.abonado;
    }
    if (appointmentStatus == 'COMPLETADA' || chargeStatus == 'PENDING') {
      return ServicePhase.porAprobar;
    }
    return esHoy ? ServicePhase.hoy : ServicePhase.agendado;
  }

  bool get esHoy {
    final DateTime now = DateTime.now();
    return serviceDate.year == now.year &&
        serviceDate.month == now.month &&
        serviceDate.day == now.day;
  }

  /// `09:00` a partir del `09:00:00` que manda el back. Nulo si no hay hora.
  String? get hora {
    final String? raw = startTime;
    if (raw == null || raw.length < 5) return null;
    return raw.substring(0, 5);
  }

  /// `09:00 – 09:45`, o solo la hora de inicio si no hay fin.
  String? get franja {
    final String? ini = hora;
    if (ini == null) return null;
    final String? fin =
        (endTime != null && endTime!.length >= 5) ? endTime!.substring(0, 5) : null;
    return fin == null ? ini : '$ini – $fin';
  }

  /// La fila a partir de la CITA, con lo que el cargo añada si ya existe.
  factory ServiceItem.deCita(AgendaAppointment cita, ServiceItem? cargo) => ServiceItem(
        appointmentId: cita.id,
        appointmentStatus: cita.status,
        chargeId: cargo?.chargeId,
        chargeStatus: cargo?.chargeStatus,
        serviceName: cita.serviceName,
        serviceDate: cita.localDate,
        startTime: _hhmm(cita.startUtc),
        endTime: _hhmm(cita.endUtc),
        clientName: cita.clientName,
        clientEmail: cargo?.clientEmail,
        clientPhone: cita.clientPhone ?? cargo?.clientPhone,
        grossAmount: cita.totalPrice,
        deductionRate: cargo?.deductionRate ?? 0,
        netAmount: cargo?.netAmount ?? 0,
        paymentMethod: cargo?.paymentMethod ?? 'CASH',
        settlementId: cargo?.settlementId,
        discardReason: cargo?.discardReason,
        resultPhotoUrl: cargo?.resultPhotoUrl,
      );

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        chargeId: j['id'].toString(),
        appointmentId: j['appointmentId']?.toString(),
        chargeStatus: (j['status'] ?? 'SCHEDULED').toString(),
        serviceName: (j['serviceName'] ?? '').toString(),
        serviceDate: DateTime.tryParse((j['serviceDate'] ?? '').toString()) ?? DateTime.now(),
        startTime: j['startTime']?.toString(),
        endTime: j['endTime']?.toString(),
        clientName: (j['clientName'] ?? 'Cliente').toString(),
        clientEmail: j['clientEmail'] as String?,
        clientPhone: j['clientPhone'] as String?,
        grossAmount: _num(j['grossAmount']),
        deductionRate: _num(j['deductionRate']),
        netAmount: _num(j['netAmount']),
        paymentMethod: (j['paymentMethod'] ?? 'CASH').toString(),
        settlementId: j['settlementId']?.toString(),
        discardReason: j['discardReason'] as String?,
        resultPhotoUrl: j['resultPhotoUrl'] as String?,
      );

  static double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class ServiceChargeRepository {
  ServiceChargeRepository(this._client);
  final ApiClient _client;

  Future<List<ServiceItem>> ofEmployee(String employeeId) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('finance/service-charges/employee/$employeeId');
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final serviceChargeRepositoryProvider =
    Provider<ServiceChargeRepository>((ref) => ServiceChargeRepository(ref.watch(apiClientProvider)));

/// Cuánto se mira hacia atrás y hacia adelante al pedir la agenda.
///
/// Adelante, porque agendar con un mes de antelación es normal. Atrás poco: lo
/// viejo ya no es agenda, es historial, y ese lo traen los cargos, que además
/// vienen con la comisión y el estado de aprobación.
const Duration _atras = Duration(days: 15);
const Duration _adelante = Duration(days: 60);

/// Todos los servicios del empleado logueado: sus citas, con su dinero.
///
/// Lista vacía si aún no tiene registro laboral o falla la red: quedarse sin
/// pantalla por un fallo de cobertura sería peor que verla vacía.
final myServicesProvider = FutureProvider<List<ServiceItem>>((ref) async {
  final EmployeeBalance balance = await ref.watch(myBalanceProvider.future);
  final String? employeeId = balance.employeeId;
  if (employeeId == null) return const [];

  final AgendaRepository agenda = ref.read(agendaRepositoryProvider);

  // Antes de leer, poner los cargos al día: así el empleado ve su comisión sin
  // esperar a que el dueño abra el panel. Si falla, la lista sale igual — solo
  // que las citas nuevas se verán con el precio y no con su parte.
  final String? businessId = balance.businessId;
  if (businessId != null) {
    try {
      await agenda.syncCharges(businessId);
    } catch (_) {
      // Sin cargos al día se sigue: la agenda no depende de finance.
    }
  }

  final DateTime hoy = DateTime.now();
  final List<AgendaAppointment> citas;
  final List<ServiceItem> cargos;
  try {
    final List<dynamic> r = await Future.wait(<Future<dynamic>>[
      agenda.ofEmployee(employeeId, from: hoy.subtract(_atras), to: hoy.add(_adelante)),
      ref.read(serviceChargeRepositoryProvider).ofEmployee(employeeId),
    ]);
    citas = (r[0] as List<dynamic>).cast<AgendaAppointment>();
    cargos = (r[1] as List<dynamic>).cast<ServiceItem>();
  } catch (_) {
    return const [];
  }

  final Map<String, ServiceItem> cargoPorCita = {
    for (final ServiceItem c in cargos)
      if (c.appointmentId != null) c.appointmentId!: c,
  };
  final Set<String> conCita = {for (final AgendaAppointment a in citas) a.id};

  // Las citas mandan, y detrás van los cargos que no tienen cita en la ventana
  // (el historial viejo, y cualquier cargo suelto).
  return <ServiceItem>[
    for (final AgendaAppointment c in citas) ServiceItem.deCita(c, cargoPorCita[c.id]),
    for (final ServiceItem c in cargos)
      if (c.appointmentId == null || !conCita.contains(c.appointmentId)) c,
  ];
});

/// Lo de HOY, ordenado por hora. Es lo que abre la app y lo único accionable.
final todayServicesProvider = Provider<List<ServiceItem>>((ref) {
  final List<ServiceItem> all = ref.watch(myServicesProvider).valueOrNull ?? const [];
  return all
      .where((s) => s.phase == ServicePhase.hoy || s.phase == ServicePhase.enCurso)
      .toList()
    ..sort((a, b) => (a.hora ?? '').compareTo(b.hora ?? ''));
});
