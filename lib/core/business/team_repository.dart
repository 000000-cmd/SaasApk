import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/business/business_repository.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

class Branch {
  final String id;
  final String name;
  const Branch({required this.id, required this.name});

  factory Branch.fromJson(Map<String, dynamic> j) =>
      Branch(id: j['id'].toString(), name: (j['name'] ?? '').toString());
}

/// Colaborador con la persona ya resuelta por el back (nombre + foto salen del
/// read model de Elasticsearch; ver EmployeeController.detailedByBranch).
class TeamMember {
  final String id;
  final String personName;
  final String? photoUrl;
  final String branchId;
  final String branchName;

  const TeamMember({
    required this.id,
    required this.personName,
    required this.photoUrl,
    required this.branchId,
    required this.branchName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j, String branchName) => TeamMember(
        id: j['id'].toString(),
        personName: (j['personName'] ?? '').toString().trim(),
        photoUrl: j['photoUrl'] as String?,
        branchId: (j['branchId'] ?? '').toString(),
        branchName: branchName,
      );

  /// Alta mínima: el empleado aún no completó su perfil desde el APK.
  bool get isPending => personName.isEmpty || personName == '—';
  String get displayName => isPending ? 'Pendiente de completar' : personName;
}

class TeamRepository {
  TeamRepository(this._client);
  final ApiClient _client;

  Future<List<Branch>> branches(String businessId) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('business/branches', queryParameters: {'businessId': businessId});
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TeamMember>> membersOf(Branch branch) async {
    final Response<dynamic> res = await _client.dio
        .get<dynamic>('business/employees/detailed', queryParameters: {'branchId': branch.id});
    final List<dynamic> data = ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    return data.map((e) => TeamMember.fromJson(e as Map<String, dynamic>, branch.name)).toList();
  }
}

final teamRepositoryProvider =
    Provider<TeamRepository>((ref) => TeamRepository(ref.watch(apiClientProvider)));

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final MyBusiness? business = await ref.watch(myBusinessProvider.future);
  if (business == null) return const [];
  try {
    return await ref.read(teamRepositoryProvider).branches(business.id);
  } catch (_) {
    return const [];
  }
});

/// Equipo completo del negocio (se unen todas las sedes: el listado del back es
/// por sede). Lista vacía ante cualquier fallo — la pantalla lo muestra vacío.
final teamProvider = FutureProvider<List<TeamMember>>((ref) async {
  final List<Branch> branches = await ref.watch(branchesProvider.future);
  if (branches.isEmpty) return const [];
  final TeamRepository repo = ref.read(teamRepositoryProvider);
  try {
    final List<List<TeamMember>> lists =
        await Future.wait(branches.map(repo.membersOf));
    return lists.expand((e) => e).toList();
  } catch (_) {
    return const [];
  }
});
