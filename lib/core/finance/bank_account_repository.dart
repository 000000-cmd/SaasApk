import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Las dos formas de recibir plata.
enum AccountKind {
  bank,
  brev;

  String get code => this == AccountKind.brev ? 'BREV' : 'BANK';

  static AccountKind from(String? raw) =>
      raw == 'BREV' ? AccountKind.brev : AccountKind.bank;
}

/// Una cuenta a la que le pueden consignar la nómina al colaborador.
class BankAccount {
  final String id;
  final AccountKind kind;
  final String? bankName;
  final String? accountType;
  final String? accountNumber;
  final String? brevKey;
  final String? alias;
  final bool isPrimary;

  /// "Bancolombia · Ahorros · ···4590". Lo compone el back para que la app, la
  /// web y el comprobante digan exactamente lo mismo.
  final String label;

  const BankAccount({
    required this.id,
    required this.kind,
    required this.isPrimary,
    required this.label,
    this.bankName,
    this.accountType,
    this.accountNumber,
    this.brevKey,
    this.alias,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['id'].toString(),
        kind: AccountKind.from(j['accountKind']?.toString()),
        bankName: j['bankName'] as String?,
        accountType: j['accountType'] as String?,
        accountNumber: j['accountNumber'] as String?,
        brevKey: j['brevKey'] as String?,
        alias: j['alias'] as String?,
        isPrimary: j['isPrimary'] == true,
        label: (j['label'] ?? '').toString(),
      );
}

/// Un banco del catálogo.
class BankOption {
  const BankOption(this.id, this.name);
  final String id;
  final String name;
}

class BankAccountRepository {
  BankAccountRepository(this._client);
  final ApiClient _client;

  /// La persona detrás de la cuenta de usuario. Las cuentas son SUYAS, no del
  /// registro laboral: si mañana trabaja en otra sede, se las lleva.
  Future<String?> myThirdPartyId(String userId) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('thirdparty/third-parties/by-user/$userId');
    final Map<String, dynamic>? data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
    return data?['id']?.toString();
  }

  /// El catálogo de bancos.
  ///
  /// Lo sirve thirdparty y no `system/list/bank`, que responde 404: `bank`
  /// nunca se registró como catálogo dinámico. El síntoma era un desplegable
  /// vacío, sin error visible, y con él no se podía elegir banco ni registrar
  /// dónde te pagan.
  Future<List<BankOption>> banks() async {
    final Response<dynamic> res = await _client.dio.get<dynamic>('thirdparty/bank-accounts/banks');
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data
        .map((e) => BankOption(
              (e as Map<String, dynamic>)['id'].toString(),
              (e['name'] ?? '').toString(),
            ),)
        .toList();
  }

  Future<List<BankAccount>> ofPerson(String thirdPartyId) async {
    final Response<dynamic> res = await _client.dio.get<dynamic>(
      'thirdparty/bank-accounts',
      queryParameters: <String, dynamic>{'thirdPartyId': thirdPartyId},
    );
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => BankAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Da de alta una cuenta. La primera queda como principal sin preguntar: la
  /// única respuesta posible a "¿es tu principal?" con una sola cuenta es sí.
  Future<void> create({
    required String thirdPartyId,
    required AccountKind kind,
    String? bankId,
    String? accountType,
    String? accountNumber,
    String? brevKey,
    String? alias,
    bool isPrimary = false,
  }) async {
    await _client.dio.post<dynamic>('thirdparty/bank-accounts', data: <String, dynamic>{
      'thirdPartyId': thirdPartyId,
      'accountKind': kind.code,
      if (bankId != null) 'bankId': bankId,
      if (accountType != null) 'accountType': accountType,
      if (accountNumber != null) 'accountNumber': accountNumber,
      // La llave BREV va TAL CUAL: ni trim, ni mayúsculas, ni quitar puntos.
      // Es literalmente lo que el banco resuelve.
      if (brevKey != null) 'brevKey': brevKey,
      if (alias != null && alias.trim().isNotEmpty) 'alias': alias.trim(),
      'isPrimary': isPrimary,
    },);
  }

  Future<void> makePrimary(String id) async {
    await _client.dio.put<dynamic>('thirdparty/bank-accounts/$id/primary');
  }

  Future<void> remove(String id) async {
    await _client.dio.delete<dynamic>('thirdparty/bank-accounts/$id');
  }
}

final bankAccountRepositoryProvider =
    Provider<BankAccountRepository>((ref) => BankAccountRepository(ref.watch(apiClientProvider)));

/// El tercero del usuario logueado. Null si su cuenta todavía no tiene persona.
final myThirdPartyIdProvider = FutureProvider<String?>((ref) async {
  final String? userId = ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return null;
  try {
    return await ref.read(bankAccountRepositoryProvider).myThirdPartyId(userId);
  } catch (_) {
    return null;
  }
});

/// Mis cuentas. Vacío si aún no hay persona o falla la red.
final myBankAccountsProvider = FutureProvider<List<BankAccount>>((ref) async {
  final String? thirdPartyId = await ref.watch(myThirdPartyIdProvider.future);
  if (thirdPartyId == null) return const [];
  try {
    return await ref.read(bankAccountRepositoryProvider).ofPerson(thirdPartyId);
  } catch (_) {
    return const [];
  }
});
