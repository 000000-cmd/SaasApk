import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/business/business_repository.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Saldo de un colaborador visto por el DUEÑO (para liquidar).
///
/// Se lee del read model de Elasticsearch, igual que en la web: rápido y sin
/// tocar la BD transaccional. Confirmar la liquidación sí va contra
/// finance-service, que es quien mueve el dinero.
class TeamBalance {
  final String employeeId;
  final String? branchId;
  final double accrued;
  final double paid;
  final double pending;
  final String currency;

  const TeamBalance({
    required this.employeeId,
    required this.branchId,
    required this.accrued,
    required this.paid,
    required this.pending,
    required this.currency,
  });

  factory TeamBalance.fromJson(Map<String, dynamic> j) => TeamBalance(
        employeeId: j['employeeId'].toString(),
        branchId: j['branchId']?.toString(),
        accrued: _num(j['amountAccrued']),
        paid: _num(j['amountPaid']),
        pending: _num(j['balance']),
        currency: (j['currency'] ?? 'COP').toString(),
      );

  static double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();
}

/// Historial de pagos del empleado logueado. Vacío si aún no tiene registro
/// laboral proyectado o si falla la red — la pantalla lo muestra como vacío.
final mySettlementsProvider = FutureProvider<List<SettlementEntry>>((ref) async {
  final EmployeeBalance balance = await ref.watch(myBalanceProvider.future);
  final String? employeeId = balance.employeeId;
  if (employeeId == null) return const [];
  try {
    return await ref.read(settlementRepositoryProvider).historyOf(employeeId);
  } catch (_) {
    return const [];
  }
});

class SettlementRepository {
  SettlementRepository(this._client);
  final ApiClient _client;

  /// Saldos de todo el negocio desde el read model (criterios por el cuerpo).
  Future<List<TeamBalance>> balances(String businessId) async {
    final Response<dynamic> res = await _client.dio.post<dynamic>(
      'search/balances',
      data: <String, dynamic>{'businessId': businessId},
    );
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => TeamBalance.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Liquidaciones recibidas por un empleado, de la más reciente a la más vieja.
  Future<List<SettlementEntry>> historyOf(String employeeId) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('finance/settlements/employee/$employeeId');
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => SettlementEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Liquida: abona al saldo del colaborador la suma de sus servicios ya
  /// aprobados. NO manda monto — lo calcula el back con lo aprobado, y mandarlo
  /// desde aquí permitiría abonar una cifra que no corresponde a ningún trabajo.
  ///
  /// IRREVERSIBLE. Si no hay nada aprobado, el back responde un error de negocio
  /// con su motivo (la pantalla lo muestra tal cual).
  Future<void> settle(String employeeId) async {
    await _client.dio.post<dynamic>(
      'finance/settlements',
      data: {'employeeId': employeeId},
    );
  }

  /// El colaborador acusa recibo de un pago EN EFECTIVO.
  ///
  /// En una transferencia el comprobante ya demuestra que la plata salió; en
  /// efectivo no hay rastro salvo que la persona diga que lo recibió. Repetirlo
  /// no cambia nada: la primera confirmación es la que vale.
  Future<void> confirmCash(String movementId, String employeeId) async {
    await _client.dio.put<dynamic>(
      'finance/settlements/$movementId/confirm-cash',
      queryParameters: <String, dynamic>{'employeeId': employeeId},
    );
  }
}

/// Dirección del dinero en el extracto del colaborador.
///
/// Los dos primeros son ABONOS (el empleado gana y su saldo sube); `payroll` es
/// la dispersión de nómina (el empleado cobra y su saldo baja). Distinguirlos es
/// lo que evita confundir "ya me lo reconocieron" con "ya me lo pagaron".
enum MovementType {
  commission,
  baseSalary,
  payroll;

  static MovementType from(String? raw) => switch (raw) {
        'BASE_SALARY' => MovementType.baseSalary,
        'PAYROLL' => MovementType.payroll,
        _ => MovementType.commission,
      };

  bool get isCredit => this != MovementType.payroll;
}

/// Un movimiento del saldo del colaborador: su extracto. Viene de la auditoría
/// de tesorería en finance-service, que es la fuente de verdad del movimiento.
class SettlementEntry {
  final String id;
  final double amount;
  final double balanceBefore;
  final DateTime settledAt;
  final String? note;

  final MovementType type;

  /// Desglose de un pago de nómina, congelado por el back. Sin él, el empleado
  /// ve un solo número y no sabe cuánto fue comisión y cuánto sueldo base.
  final double commissionAmount;
  final double baseSalaryAmount;

  /// Cuenta a la que el dueño dice haber consignado. Puede no existir: el
  /// sistema no opera con el banco.
  final String? payoutAccount;
  final String? payrollRunId;

  /// Prueba del pago: el comprobante de la transferencia, o la marca de que se
  /// entregó en mano (y entonces hace falta el acuse del colaborador).
  final String? paymentProofUrl;
  final bool paidInCash;
  final DateTime? cashConfirmedAt;

  const SettlementEntry({
    required this.id,
    required this.amount,
    required this.balanceBefore,
    required this.settledAt,
    required this.type,
    required this.commissionAmount,
    required this.baseSalaryAmount,
    this.note,
    this.payoutAccount,
    this.payrollRunId,
    this.paymentProofUrl,
    this.paidInCash = false,
    this.cashConfirmedAt,
  });

  /// Saldo que quedó tras el movimiento. Nunca negativo: un pago no puede
  /// dejar debiendo al colaborador.
  double get balanceAfter {
    final double after = type.isCredit
        ? balanceBefore + amount
        : balanceBefore - amount;
    return after < 0 ? 0 : after;
  }

  /// Si en este pago, además de la comisión, se consignó el sueldo base. Es la
  /// línea extra que el empleado con sueldo fijo necesita ver para cuadrar.
  bool get hasBaseSalary => type == MovementType.payroll && baseSalaryAmount > 0;

  /// Le pagaron en efectivo y todavía no ha confirmado que lo recibió.
  bool get cashPendingConfirmation => paidInCash && cashConfirmedAt == null;

  factory SettlementEntry.fromJson(Map<String, dynamic> j) => SettlementEntry(
        id: j['id'].toString(),
        amount: TeamBalance._num(j['amount']),
        balanceBefore: TeamBalance._num(j['balanceBefore']),
        settledAt: DateTime.tryParse((j['settledAt'] ?? '').toString()) ?? DateTime.now(),
        type: MovementType.from(j['movementType']?.toString()),
        commissionAmount: TeamBalance._num(j['commissionAmount']),
        baseSalaryAmount: TeamBalance._num(j['baseSalaryAmount']),
        note: j['note'] as String?,
        payoutAccount: j['payoutAccount'] as String?,
        payrollRunId: j['payrollRunId']?.toString(),
        paymentProofUrl: j['paymentProofUrl'] as String?,
        paidInCash: j['paidInCash'] == true,
        cashConfirmedAt: DateTime.tryParse((j['cashConfirmedAt'] ?? '').toString()),
      );
}

final settlementRepositoryProvider =
    Provider<SettlementRepository>((ref) => SettlementRepository(ref.watch(apiClientProvider)));

/// Saldos del negocio del dueño. Lista vacía si no tiene negocio o falla la red.
final teamBalancesProvider = FutureProvider<List<TeamBalance>>((ref) async {
  final MyBusiness? business = await ref.watch(myBusinessProvider.future);
  if (business == null) return const [];
  try {
    return await ref.read(settlementRepositoryProvider).balances(business.id);
  } catch (_) {
    return const [];
  }
});
