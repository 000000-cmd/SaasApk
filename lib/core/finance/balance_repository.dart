import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Saldo por cobrar del empleado, leído del READ MODEL en Elasticsearch
/// (search-service). Rápido y desacoplado de la BD transaccional. Si aún no hay
/// proyección (o sin red), el saldo se asume 0 — nunca rompe el dashboard.
class EmployeeBalance {
  final double balance;
  final double accrued;
  final double paid;
  final String currency;

  /// Id del registro laboral. El APK solo conoce el userId; este campo llega
  /// en el read model y es la llave para pedir el historial de liquidaciones.
  final String? employeeId;

  /// El negocio donde trabaja. El empleado no tiene negocio propio —`/business/mine`
  /// le devuelve vacío—, así que este es el único sitio donde el APK lo sabe, y
  /// hace falta para pedirle a finance que ponga sus cargos al día.
  final String? businessId;

  const EmployeeBalance({
    required this.balance,
    required this.accrued,
    required this.paid,
    required this.currency,
    this.employeeId,
    this.businessId,
  });

  static const zero = EmployeeBalance(balance: 0, accrued: 0, paid: 0, currency: 'COP');

  factory EmployeeBalance.fromJson(Map<String, dynamic> j) => EmployeeBalance(
        balance: _num(j['balance']),
        accrued: _num(j['amountAccrued']),
        paid: _num(j['amountPaid']),
        currency: (j['currency'] ?? 'COP').toString(),
        employeeId: j['employeeId']?.toString(),
        businessId: j['businessId']?.toString(),
      );

  static double _num(dynamic v) => v == null ? 0 : (v as num).toDouble();
}

class BalanceRepository {
  BalanceRepository(this._client);
  final ApiClient _client;

  /// Saldo del usuario logueado desde ES. `null` si no hay documento todavía.
  ///
  /// Elastic se consulta siempre por POST con los criterios en el cuerpo, y
  /// responde una lista: aquí solo puede haber un saldo por cuenta.
  Future<EmployeeBalance?> ofUser(String userId) async {
    final Response<dynamic> res = await _client.dio.post<dynamic>(
      'search/balances',
      data: <String, dynamic>{'userId': userId},
    );
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    if (data.isEmpty) return null;
    return EmployeeBalance.fromJson(data.first as Map<String, dynamic>);
  }
}

final balanceRepositoryProvider =
    Provider<BalanceRepository>((ref) => BalanceRepository(ref.watch(apiClientProvider)));

/// Saldo del usuario logueado; [EmployeeBalance.zero] si no hay dato o falla la red.
final myBalanceProvider = FutureProvider<EmployeeBalance>((ref) async {
  final String? userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return EmployeeBalance.zero;
  try {
    return (await ref.read(balanceRepositoryProvider).ofUser(userId)) ?? EmployeeBalance.zero;
  } catch (_) {
    return EmployeeBalance.zero;
  }
});
