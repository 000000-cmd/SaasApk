import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/features/home/dashboard_screen.dart';
import 'package:saas_app/features/more/more_screen.dart';
import 'package:saas_app/features/services/services_screen.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/menu/menu_controller.dart';
import 'package:saas_app/core/menu/menu_models.dart';
import 'package:saas_app/features/home/welcome_tour.dart';
import 'package:saas_app/features/owner/owner_dashboard_screen.dart';
import 'package:saas_app/features/owner/owner_settlements_screen.dart';
import 'package:saas_app/features/owner/owner_team_screen.dart';
import 'package:saas_app/features/payments/payments_screen.dart';
import 'package:saas_app/features/profile/profile_screen.dart';
import 'package:saas_app/shared/widgets/app_nav_bar.dart';

/// Shell principal: SIN drawer y SIN AppBar — la app vive en 4 pestañas de una
/// barra inferior (Inicio / Servicios / Movimientos / Más para el colaborador).
/// La razón de entrar es ver el saldo, así que Inicio abre con él.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
  }

  /// Primer ingreso al panel: tour de bienvenida con ORB. Luego (si aplica),
  /// la oferta de huella. El ORB vive aquí, no en la tarjeta de saldo.
  Future<void> _onFirstFrame() async {
    final AuthController controller = ref.read(authControllerProvider.notifier);
    if (controller.shouldShowWelcome()) {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      final String name = (user?.fullName ?? user?.username ?? '').split(' ').first;
      await WelcomeTour.show(context, name: name);
      await controller.markWelcomeShown();
    }
    if (!mounted) return;
    if (ref.read(authControllerProvider).offerBiometrics) await _offerBiometrics();
  }

  Future<void> _offerBiometrics() async {
    final bool? enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        title: const Text('¿Entrar con huella?'),
        content: const Text('Usa tu huella para entrar más rápido la próxima vez. Puedes cambiarlo en tu perfil.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ahora no')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    final AuthController controller = ref.read(authControllerProvider.notifier);
    if (enable == true) {
      await controller.enableBiometrics();
    } else {
      await controller.declineBiometrics();
    }
  }

  @override
  Widget build(BuildContext context) {
    // El APK sirve a DOS roles con recorridos distintos: el dueño supervisa y
    // libera comisiones; el empleado consulta su saldo y su historial.
    final bool isOwner = ref.watch(authControllerProvider).user?.kind == UserKind.owner;
    void go(int i) => setState(() => _index = i);

    // Las pestañas salen del arbol de menus configurado por rol, igual que el
    // sidebar de la web: lo que el administrador enciende, apaga o reordena se
    // ve aqui sin tocar la app. Los submenus quedan fuera — su sitio es el nav
    // secundario de su padre, no una pestaña.
    final List<_Tab> tabs = _tabsFrom(ref.watch(menuControllerProvider), isOwner: isOwner);

    // El indice puede quedar fuera de rango si el menu encoge entre cargas.
    final int index = _index.clamp(0, tabs.length - 1);

    return PopScope(
      // El "atras" del telefono NUNCA cierra la app de golpe. Desde cualquier
      // pestaña vuelve al inicio —que es el punto de partida y desde donde se
      // sale a todo lo demas— y solo estando YA en el inicio pregunta si se
      // quiere cerrar sesion. Las pantallas apiladas (bandeja, cuentas, perfil)
      // no llegan aqui: las cierra el Navigator, que es lo esperado.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          go(0);
          return;
        }
        _confirmLogout();
      },
      child: Scaffold(
        // La barra va anclada al borde: el Scaffold le reserva su alto y el
        // contenido termina justo encima, sin quedar tapado.
        body: IndexedStack(
          index: index,
          children: [for (final t in tabs) t.build(go)],
        ),
        bottomNavigationBar: AppNavBar(
          index: index,
          onTap: go,
          items: [for (final t in tabs) t.item],
        ),
      ),
    );
  }

  /// Atras estando en el inicio: preguntar si cerrar sesion.
  ///
  /// Antes era el doble toque para SALIR de la app, que no vaciaba la sesion:
  /// la siguiente persona que abriera el telefono entraba directa a la cuenta
  /// anterior. Volver a entrar cuesta la huella; volver a la cuenta de otro no
  /// deberia costar nada menos que decir que si.
  Future<void> _confirmLogout() async {
    final bool? salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a entrar con tu usuario y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Quedarme')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (salir == true) await ref.read(authControllerProvider.notifier).logout();
  }

  /// Traduce el arbol de menus a pestañas.
  ///
  /// SOLO para el DUEÑO. El empleado lleva sus cuatro pestañas fijas y no pasa
  /// por aqui, y la razon es un fallo real: el arbol de menus describe el
  /// SIDEBAR DE LA WEB, no el APK. Al empleado le llegan dos entradas —"Panel"
  /// (/tenant/dashboard) y "Mi perfil" (/tenant/profile)— que son sus pantallas
  /// del navegador. Como 'dashboard' existia en el mapa y apuntaba al panel del
  /// DUEÑO, un empleado entraba y se encontraba con los saldos de todo el
  /// equipo y el boton de liquidar. Ademas perdia Servicios y Movimientos, que
  /// no tienen menu porque solo existen en el telefono.
  ///
  /// Si el back no responde o ninguna ruta tiene pantalla conocida, se cae a
  /// las pestañas de siempre: quedarse sin navegacion por un fallo de red seria
  /// mucho peor que enseñar un menu algo desactualizado.
  List<_Tab> _tabsFrom(List<MenuNode> tree, {required bool isOwner}) {
    if (!isOwner) return _employeeFallback;
    if (tree.isEmpty) return _ownerFallback;

    final fallback = _ownerFallback;
    final tabs = <_Tab>[];
    for (final node in navigableLeaves(tree)) {
      final build = _ownerScreens[node.routeKey];
      if (build == null) continue; // menu sin pantalla en el APK: no se pinta
      tabs.add(_Tab(
        key: node.routeKey,
        item: AppNavItem(
          icon: menuIconFor(node.icon),
          activeIcon: menuIconFor(node.icon),
          label: node.name,
          locked: _locked.contains(node.routeKey),
        ),
        build: build,
      ),);
    }

    // Con menos de dos destinos esto no es una app, es una pantalla suelta.
    // Pasa de verdad: en la web varias funciones viven dentro del dock de "Mi
    // empresa" (son submenus) y esa ruta no tiene pantalla en el APK, asi que
    // una configuracion perfectamente valida para la web dejaria el telefono
    // sin navegacion. Antes que eso, las pestañas de siempre.
    if (tabs.length < 2) return fallback;

    // El perfil no es un menu de negocio: es la cuenta — cambiar la clave, la
    // huella, cerrar sesion. No puede depender de la configuracion.
    if (!tabs.any((t) => t.key == 'profile')) {
      tabs.add(fallback.firstWhere((t) => t.key == 'profile'));
    }
    return tabs;
  }

  /// Que pantalla abre cada ruta DEL DUEÑO. Es lo unico que sigue en codigo: la
  /// pantalla es un widget y alguien tiene que decir cual. QUE menus hay, como
  /// se llaman y en que orden lo decide la configuracion.
  ///
  /// Va con el rol en el nombre a proposito. Un mapa unico compartido por los
  /// dos roles fue exactamente el fallo: bastaba que la configuracion del
  /// empleado tuviera una ruta con el mismo ultimo tramo para servirle una
  /// pantalla del dueño.
  static final Map<String, Widget Function(void Function(int))> _ownerScreens = {
    'dashboard': (go) => OwnerDashboardScreen(onNavigate: go),
    'liquidaciones': (_) => const OwnerSettlementsScreen(),
    'empleados': (_) => const OwnerTeamScreen(),
    'profile': (_) => const ProfileScreen(),
  };

  /// Rutas que se ven pero todavia no operan (candado en la pestaña).
  ///
  /// Vacio: la que estaba bloqueada era Citas, y ahora la agenda del empleado
  /// existe de verdad dentro de Servicios.
  static const Set<String> _locked = {};

  // ── Reserva ────────────────────────────────────────────────────────────────
  // Lo que se pinta cuando el arbol de menus no ha llegado (arranque en frio,
  // sin red, o una configuracion que no mapea a ninguna pantalla del APK).

  static final List<_Tab> _ownerFallback = [
    _Tab(
      item: const AppNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Panel'),
      build: (go) => OwnerDashboardScreen(onNavigate: go),
    ),
    _Tab(
      item: const AppNavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded, label: 'Liquidar'),
      build: (_) => const OwnerSettlementsScreen(),
    ),
    _Tab(
      item: const AppNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Equipo'),
      build: (_) => const OwnerTeamScreen(),
    ),
    _Tab(
      key: 'profile',
      item: const AppNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil'),
      build: (_) => const ProfileScreen(),
    ),
  ];

  /// Las cuatro del empleado, en el orden en que las necesita:
  ///
  ///   Inicio      lo de hoy y su saldo — la razón de abrir la app;
  ///   Servicios   su trabajo: la agenda y todo lo prestado, con su estado;
  ///   Movimientos su plata: lo que se le abonó y lo que se le consignó;
  ///   Más         lo suyo: perfil, cuentas, notificaciones.
  ///
  /// Trabajo y plata van SEPARADOS a propósito. Mezclarlos es lo que hacía que
  /// una pantalla tuviera citas, saldos y pagos a la vez y no se entendiera
  /// ninguna de las tres.
  static final List<_Tab> _employeeFallback = [
    _Tab(
      item: const AppNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio'),
      build: (go) => DashboardScreen(onNavigate: go),
    ),
    _Tab(
      key: 'citas',
      item: const AppNavItem(
        icon: Icons.content_cut_outlined,
        activeIcon: Icons.content_cut_rounded,
        label: 'Servicios',
      ),
      build: (_) => const ServicesScreen(),
    ),
    _Tab(
      key: 'pagos',
      item: const AppNavItem(
        icon: Icons.swap_vert_rounded,
        activeIcon: Icons.swap_vert_rounded,
        label: 'Movimientos',
      ),
      build: (_) => const PaymentsScreen(),
    ),
    _Tab(
      key: 'profile',
      item: const AppNavItem(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: 'Más',
      ),
      build: (_) => const MoreScreen(),
    ),
  ];
}

/// Una pestaña: lo que se ve abajo y la pantalla que abre.
class _Tab {
  const _Tab({required this.item, required this.build, this.key = ''});

  /// Último tramo de la ruta ('profile', 'liquidaciones'). Identifica la
  /// pantalla sin depender de la etiqueta, que la configuración puede cambiar.
  final String key;
  final AppNavItem item;
  final Widget Function(void Function(int) go) build;
}
