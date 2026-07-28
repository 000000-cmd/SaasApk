import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/menu/menu_models.dart';
import 'package:saas_app/core/menu/menu_repository.dart';

final menuRepositoryProvider =
    Provider<MenuRepository>((ref) => MenuRepository(ref.watch(apiClientProvider)));

final menuControllerProvider =
    NotifierProvider<MenuController, List<MenuNode>>(MenuController.new);

/// Sincroniza el árbol de menús con el ciclo de sesión: login → cargar;
/// logout → limpiar. Igual que el MenuService de la web: sin fallback
/// estático, lo que se ve es la config por rol de la BD.
class MenuController extends Notifier<List<MenuNode>> {
  @override
  List<MenuNode> build() {
    ref.listen(authControllerProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        _load();
      } else if (!next.isAuthenticated) {
        state = const [];
      }
    });
    if (ref.read(authControllerProvider).isAuthenticated) {
      Future.microtask(_load);
    }
    return const [];
  }

  Future<void> _load() async {
    try {
      state = await ref.read(menuRepositoryProvider).myTree();
    } catch (_) {
      state = const []; // sin red: el drawer queda vacío, no inventamos menús
    }
  }

  Future<void> refresh() => _load();
}
