import 'package:dio/dio.dart';
import 'package:saas_app/core/menu/menu_models.dart';
import 'package:saas_app/core/network/api_client.dart';

/// Menús visibles para el usuario actual según sus roles (config en BD).
class MenuRepository {
  MenuRepository(this._client);
  final ApiClient _client;

  Future<List<MenuNode>> myTree() async {
    final Response<dynamic> res = await _client.dio.get<dynamic>('system/menus/me');
    final List<dynamic> data =
        ((res.data as Map<String, dynamic>)['data'] as List?) ?? const [];
    final List<MenuNode> nodes =
        data.map((n) => MenuNode.fromJson(n as Map<String, dynamic>)).toList();
    nodes.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return nodes;
  }
}
