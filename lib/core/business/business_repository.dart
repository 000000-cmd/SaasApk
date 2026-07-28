import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Vista mínima del negocio del usuario (lo que el dashboard necesita).
class MyBusiness {
  final String id;
  final String name;
  final String? tradeName;

  const MyBusiness({required this.id, required this.name, this.tradeName});

  factory MyBusiness.fromJson(Map<String, dynamic> j) => MyBusiness(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        tradeName: j['tradeName'] as String?,
      );
}

class BusinessRepository {
  BusinessRepository(this._client);
  final ApiClient _client;

  /// Negocio(s) del usuario (dueño). Para un empleado la lista viene vacía.
  Future<MyBusiness?> mine(String userId) async {
    final Response<dynamic> res =
        await _client.dio.get<dynamic>('business/mine', queryParameters: {'userId': userId});
    final List<dynamic> data =
        ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    if (data.isEmpty) return null;
    return MyBusiness.fromJson(data.first as Map<String, dynamic>);
  }
}

final businessRepositoryProvider =
    Provider<BusinessRepository>((ref) => BusinessRepository(ref.watch(apiClientProvider)));

/// Negocio del usuario logueado; null si no tiene (empleado o dueño sin aprovisionar).
final myBusinessProvider = FutureProvider<MyBusiness?>((ref) async {
  final String? userId =
      ref.watch(authControllerProvider.select((s) => s.user?.id));
  if (userId == null) return null;
  try {
    return await ref.read(businessRepositoryProvider).mine(userId);
  } catch (_) {
    return null; // sin red o sin permiso: el dashboard lo muestra como "sin negocio"
  }
});
