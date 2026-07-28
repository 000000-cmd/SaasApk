import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/features/appointments/appointments_screen.dart';
import 'package:saas_app/features/home/dashboard_screen.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/menu/menu_controller.dart';
import 'package:saas_app/core/menu/menu_models.dart';
import 'package:saas_app/features/home/welcome_tour.dart';
import 'package:saas_app/features/owner/owner_dashboard_screen.dart';
import 'package:saas_app/features/owner/owner_settlements_screen.dart';
import 'package:saas_app/features/owner/owner_team_screen.dart';
import 'package:saas_app/features/payments/payments_screen.dart';
import 'package:saas_app/features/profile/profile_screen.dart';
import 'package:saas_app/shared/widgets/orb_nav_bar.dart';

/// Shell principal: SIN drawer y SIN AppBar — la app vive en 4 tabs de una
/// navbar de footer (Inicio / Citas / Pagos / Perfil). La razón de entrar es
/// ver el saldo, así que Inicio abre con él; lo demás queda a un toque.
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
      // El "atras" del telefono NO cierra la app. Desde una pestaña interna
      // vuelve a la primera, y desde la primera hay que confirmarlo pulsando
      // dos veces: salirse sin querer estando dentro es de lo mas molesto que
      // le puede pasar a alguien que solo queria retroceder una pantalla.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (index != 0) {
          go(0);
          return;
        }
        _confirmExit();
      },
      child: Scaffold(
        // La barra flota ENCIMA del contenido: sin `extendBody` el Scaffold le
        // reserva su alto y quedaria una franja muerta bajo el desplazamiento.
        extendBody: true,
        body: IndexedStack(
          index: index,
          children: [for (final t in tabs) t.build(go)],
        ),
        bottomNavigationBar: OrbNavBar(
          index: index,
          onTap: go,
          items: [for (final t in tabs) t.item],
        ),
      ),
    );
  }

  DateTime? _lastBackPress;

  /// Doble "atras" para salir, con aviso. Es el gesto que ya conoce cualquiera
  /// que use Android; el aviso existe para que el primer toque no parezca que
  /// la app se quedo colgada.
  void _confirmExit() {
    final DateTime now = DateTime.now();
    final bool recent =
        _lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2);
    if (recent) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Vuelve a tocar atrás para salir'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            // Por encima de la barra flotante, no debajo.
            bottom: MediaQuery.viewPaddingOf(context).bottom + 88,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        ),
      );
  }

  /// Traduce el arbol de menus a pestañas.
  ///
  /// Si el back no responde o ninguna ruta tiene pantalla conocida, se cae a
  /// las pestañas de siempre: quedarse sin navegacion por un fallo de red seria
  /// mucho peor que enseñar un menu algo desactualizado.
  List<_Tab> _tabsFrom(List<MenuNode> tree, {required bool isOwner}) {
    final fallback = isOwner ? _ownerFallback : _employeeFallback;
    if (tree.isEmpty) return fallback;

    final tabs = <_Tab>[];
    for (final node in navigableLeaves(tree)) {
      final build = _screens[node.routeKey];
      if (build == null) continue; // menu sin pantalla en el APK: no se pinta
      tabs.add(_Tab(
        key: node.routeKey,
        item: OrbNavItem(
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

  /// Que pantalla abre cada ruta. Es lo unico que sigue en codigo: la pantalla
  /// es un widget y alguien tiene que decir cual. QUE menus hay, como se
  /// llaman y en que orden lo decide la configuracion.
  static final Map<String, Widget Function(void Function(int))> _screens = {
    'dashboard': (go) => OwnerDashboardScreen(onNavigate: go),
    'liquidaciones': (_) => const OwnerSettlementsScreen(),
    'empleados': (_) => const OwnerTeamScreen(),
    'profile': (_) => const ProfileScreen(),
    'citas': (_) => const AppointmentsScreen(),
    'pagos': (_) => const PaymentsScreen(),
  };

  /// Rutas que se ven pero todavia no operan (candado en la pestaña).
  static const Set<String> _locked = {'citas'};

  // ── Reserva ────────────────────────────────────────────────────────────────
  // Lo que se pinta cuando el arbol de menus no ha llegado (arranque en frio,
  // sin red, o una configuracion que no mapea a ninguna pantalla del APK).

  static final List<_Tab> _ownerFallback = [
    _Tab(
      item: const OrbNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Panel'),
      build: (go) => OwnerDashboardScreen(onNavigate: go),
    ),
    _Tab(
      item: const OrbNavItem(icon: Icons.payments_outlined, activeIcon: Icons.payments_rounded, label: 'Liquidar'),
      build: (_) => const OwnerSettlementsScreen(),
    ),
    _Tab(
      item: const OrbNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Equipo'),
      build: (_) => const OwnerTeamScreen(),
    ),
    _Tab(
      key: 'profile',
      item: const OrbNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil'),
      build: (_) => const ProfileScreen(),
    ),
  ];

  static final List<_Tab> _employeeFallback = [
    _Tab(
      item: const OrbNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Inicio'),
      build: (go) => DashboardScreen(onNavigate: go),
    ),
    _Tab(
      item: const OrbNavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: 'Citas',
        locked: true,
      ),
      build: (_) => const AppointmentsScreen(),
    ),
    _Tab(
      item: const OrbNavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'Pagos'),
      build: (_) => const PaymentsScreen(),
    ),
    _Tab(
      key: 'profile',
      item: const OrbNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Perfil'),
      build: (_) => const ProfileScreen(),
    ),
  ];
}

/// Una pestaña: lo que se ve abajo y la pantalla que abre.
class _Tab {
  const _Tab({required this.item, required this.build, this.key = ''});

  /// Último tramo de la ruta ('profile', 'liquidaciones'). Identifica la
  /// pantalla sin depender de la etiqueta, que la configuración puede cambiar.
  final String key;
  final OrbNavItem item;
  final Widget Function(void Function(int) go) build;
}
