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

  /// Confirma la liquidación de un colaborador. Sin monto, paga todo lo pendiente.
  /// IRREVERSIBLE: mueve el saldo y queda en la auditoría de tesorería.
  Future<void> settle(String employeeId, {double? amount}) async {
    await _client.dio.post<dynamic>(
      'finance/settlements',
      data: {
        'employeeId': employeeId,
        if (amount != null) 'amount': amount,
      },
    );
  }
}

/// Una liquidación recibida por el empleado (su "pago"). Viene de la auditoría
/// de tesorería en finance-service, que es la fuente de verdad del movimiento.
class SettlementEntry {
  final String id;
  final double amount;
  final double balanceBefore;
  final DateTime settledAt;
  final String? note;

  const SettlementEntry({
    required this.id,
    required this.amount,
    required this.balanceBefore,
    required this.settledAt,
    this.note,
  });

  factory SettlementEntry.fromJson(Map<String, dynamic> j) => SettlementEntry(
        id: j['id'].toString(),
        amount: TeamBalance._num(j['amount']),
        balanceBefore: TeamBalance._num(j['balanceBefore']),
        settledAt: DateTime.tryParse((j['settledAt'] ?? '').toString()) ?? DateTime.now(),
        note: j['note'] as String?,
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
