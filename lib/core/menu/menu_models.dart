import 'package:flutter/material.dart';

/// Nodo del árbol de menús configurado por rol (espejo de /system/menus/me).
class MenuNode {
  final String id;
  final String code;
  final String name;
  final String? icon;
  final String? route;
  final int displayOrder;

  /// true = no ocupa sitio propio en la navegación; se dibuja dentro del nav
  /// secundario de su padre (en la web, el dock de "Mi empresa"). Lo decide el
  /// administrador. Aquí sirve para NO pintarlo como pestaña.
  final bool submenu;
  final List<MenuNode> children;

  const MenuNode({
    required this.id,
    required this.code,
    required this.name,
    this.icon,
    this.route,
    this.displayOrder = 0,
    this.submenu = false,
    this.children = const [],
  });

  factory MenuNode.fromJson(Map<String, dynamic> j) => MenuNode(
        id: j['id'].toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        icon: j['icon'] as String?,
        route: j['route'] as String?,
        displayOrder: (j['displayOrder'] as num?)?.toInt() ?? 0,
        submenu: j['submenu'] == true,
        children: ((j['children'] as List?) ?? const [])
            .map((c) => MenuNode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  /// Último tramo de la ruta: '/tenant/liquidaciones' → 'liquidaciones'.
  /// Es la clave con la que la app decide qué pantalla abre cada menú.
  String get routeKey {
    final path = (route ?? '').split('?').first;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? '' : parts.last;
  }
}

/// Aplana el árbol quedándose con lo NAVEGABLE: nada de submenús (esos viven
/// dentro del nav de su padre) y nada de nodos sin ruta (los grupos son
/// encabezados, no destinos).
List<MenuNode> navigableLeaves(List<MenuNode> nodes) {
  final out = <MenuNode>[];
  void walk(List<MenuNode> ns) {
    for (final n in ns) {
      if (n.submenu) continue;
      if ((n.route ?? '').isNotEmpty) out.add(n);
      walk(n.children);
    }
  }

  walk(nodes);
  out.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return out;
}

/// El back guarda nombres de icono Lucide (config compartida con la web);
/// aquí se mapean a Material. Desconocidos caen en un punto genérico.
IconData menuIconFor(String? name) => switch (name) {
      'activity' => Icons.insights_outlined,
      'building-2' => Icons.storefront_outlined,
      'scissors' => Icons.content_cut,
      'map-pin' => Icons.place_outlined,
      'users' => Icons.group_outlined,
      'user' => Icons.person_outline,
      'plus' => Icons.add_circle_outline,
      'calendar' => Icons.calendar_today_outlined,
      'settings' => Icons.settings_outlined,
      _ => Icons.circle_outlined,
    };
