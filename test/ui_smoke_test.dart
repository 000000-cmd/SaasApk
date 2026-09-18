import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/app/theme/app_theme.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/auth/biometric_service.dart';
import 'package:saas_app/core/business/business_repository.dart';
import 'package:saas_app/core/business/team_repository.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/bank_account_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/features/auth/login_screen.dart';
import 'package:saas_app/features/auth/unlock_screen.dart';
import 'package:saas_app/shared/widgets/fingerprint_button.dart';
import 'package:saas_app/features/employee/employee_onboarding_screen.dart';
// Alias: Flutter ya exporta un `MenuController` (raw_menu_anchor) y choca.
import 'package:saas_app/core/menu/menu_controller.dart' as app_menu;
import 'package:saas_app/core/menu/menu_models.dart';
import 'package:saas_app/features/home/home_shell.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';
import 'package:saas_app/shared/widgets/app_nav_bar.dart';

/// Smoke de UI del rediseño (ORB + wizard + navbar footer + bóveda del saldo).
/// Corre en viewport de teléfono (375x812): cualquier overflow revienta el test.
/// OJO: el ORB anima en loop infinito -> usar pump(duración), NUNCA pumpAndSettle.

AppUser _owner() => const AppUser(
      id: 'o-1',
      username: 'duenodemo',
      fullName: 'Demo Dueño',
      roles: ['OWNER'],
      kind: UserKind.owner,
    );

AppUser _employee() => const AppUser(
      id: 'u-1',
      username: 'apkdemo',
      email: 'apkdemo@e2e.local',
      fullName: 'Demo Empleado',
      roles: ['EMPLOYEE'],
      kind: UserKind.employee,
    );

/// AuthController de prueba: estado fijo, sin storage ni red.
class _FakeAuth extends AuthController {
  _FakeAuth(this._initial);
  final AuthState _initial;
  bool onboardingCompleted = false;

  @override
  AuthState build() => _initial;

  @override
  Future<void> completeOnboarding() async {
    onboardingCompleted = true;
    state = state.copyWith(needsOnboarding: false);
  }

  @override
  Future<bool> isBiometricEnabledForCurrentUser() async => false;

  // Sin tocar el secure storage en tests (evita el tour de bienvenida).
  @override
  bool shouldShowWelcome() => false;

  @override
  Future<void> markWelcomeShown() async {}

  @override
  Future<void> logout() async {}
}

class _FakeBiometrics extends BiometricService {
  _FakeBiometrics({this.accepts = false});

  /// Qué devuelve el lector. Además CUENTA las llamadas, que es lo que permite
  /// afirmar que la app no pide la huella por su cuenta.
  final bool accepts;
  int calls = 0;

  // Se mantiene en false: es lo que ven el resto de pruebas, y cambiarlo altera
  // pantallas que no tienen que ver (el perfil pinta el interruptor de huella).
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return accepts;
  }
}

/// Árbol de menús fijo: evita la red y deja afirmar sobre la navegación.
class _FakeMenu extends app_menu.MenuController {
  _FakeMenu(this._tree);

  final List<MenuNode> _tree;

  @override
  List<MenuNode> build() => _tree;
}

Widget _app({
  required Widget home,
  required _FakeAuth auth,
  List<TeamBalance> balances = const [],
  List<TeamMember> team = const [],
  List<Branch> branches = const [],
  List<MenuNode> menu = const [],
  _FakeBiometrics? biometrics,
}) =>
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        biometricServiceProvider.overrideWithValue(biometrics ?? _FakeBiometrics()),
        myBusinessProvider.overrideWith(
          (ref) async => const MyBusiness(id: 'b-1', name: 'Negocio Smoke', tradeName: 'Smoke'),
        ),
        teamBalancesProvider.overrideWith((ref) async => balances),
        teamProvider.overrideWith((ref) async => team),
        branchesProvider.overrideWith((ref) async => branches),
        // Sin red en tests: si no se declaran, las pantallas se quedan en su
        // estado de carga y no se puede afirmar nada del contenido.
        myBalanceProvider.overrideWith((ref) async => EmployeeBalance.zero),
        mySettlementsProvider.overrideWith((ref) async => const <SettlementEntry>[]),
        // Sin tercero no hay a quién colgarle la cuenta: el alta termina igual
        // (es a propósito — no puede quedarse atrapado por eso).
        myThirdPartyIdProvider.overrideWith((ref) async => null),
        myBankAccountsProvider.overrideWith((ref) async => const <BankAccount>[]),
        // Vacío por defecto: así el resto de pruebas siguen ejerciendo la
        // reserva de pestañas, que es lo que se ve sin red.
        app_menu.menuControllerProvider.overrideWith(() => _FakeMenu(menu)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(375 * 3, 812 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// pumpAndSettle está vetado (el ORB anima en loop); esto avanza las
/// transiciones finitas (PageView 320ms, AnimatedSwitcher 250ms) por frames.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  // El runtime nativo de Rive no está disponible en el harness de tests; la
  // mascota usa su fallback estático (que es parte de lo que se verifica).
  OrbMascot.riveDisabled = true;

  test('formatCOP: sin decimales y con punto de miles', () {
    expect(formatCOP(0), r'$ 0');
    expect(formatCOP(1250000), r'$ 1.250.000');
    expect(formatCOP(999), r'$ 999');
  });

  testWidgets('Login: identidad con ORB + credenciales en tarjeta, sin registro',
      (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(const AuthState());
    await tester.pumpWidget(_app(home: const LoginScreen(), auth: auth));
    await _settle(tester);

    // El ORB es la identidad de marca de la pantalla.
    expect(find.byType(OrbMascot), findsOneWidget);
    expect(find.text('Moda ERP'), findsOneWidget);
    expect(find.text('Cada servicio suma'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    // Sin registro: la única puerta es el login.
    expect(find.textContaining('Tu empleador te la crea'), findsOneWidget);
    expect(find.textContaining('Regístrate'), findsNothing);
  });

  testWidgets('Wizard: 4 pasos con validación, resumen y cierre', (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth =
        _FakeAuth(AuthState(user: _employee(), needsOnboarding: true));
    await tester.pumpWidget(_app(home: const EmployeeOnboardingScreen(), auth: auth));
    await _settle(tester);

    // Paso 1: identidad. Sin documento no deja seguir.
    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('PASO 1 DE 4 · IDENTIDAD'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), ''); // documento vacío
    await tester.tap(find.text('Continuar'));
    await _settle(tester);
    expect(find.textContaining('Completa nombre'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'Demo');
    await tester.enterText(find.byType(TextField).at(1), 'Empleado');
    await tester.enterText(find.byType(TextField).at(2), '900123456');
    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    // Paso 2: contacto (opcional).
    expect(find.text('¿Cómo te contactamos?'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    // Paso 3: cuenta de pago. Es OBLIGATORIA — sin ella no deja seguir.
    expect(find.text('¿Dónde te pagamos?'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await _settle(tester);
    expect(find.textContaining('Elige tu banco'), findsWidgets);

    // La llave BREV no necesita catálogo de bancos: sirve para cerrar el alta.
    await tester.tap(find.text('Llave BREV'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'demo@correo.com');
    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    // Paso 3: resumen con lo diligenciado y lo pendiente.
    expect(find.text('Todo listo'), findsOneWidget);
    expect(find.text('Demo Empleado'), findsOneWidget);
    // El resumen antepone el tipo (Cédula de ciudadanía: …) y el número va
    // agrupado de a tres, que es como se lee una cédula.
    expect(find.textContaining('900.123.456'), findsOneWidget);
    expect(find.text('Sin diligenciar'), findsWidgets);

    await tester.tap(find.text('Empezar'));
    // El cierre espera 450 ms para que se vea la celebración del ORB.
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(auth.onboardingCompleted, isTrue);
  });

  testWidgets('Home: saldo protagonista + retícula de resumen + navbar de 4 tabs',
      (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(AuthState(user: _employee()));
    await tester.pumpWidget(_app(home: const HomeShell(), auth: auth));
    await _settle(tester);

    // La razón de entrar: el saldo, gigante y arriba.
    // El titular es el saldo acumulado del periodo, no una deuda vencida.
    expect(find.text('TU SALDO'), findsOneWidget);
    expect(find.text(r'$ 0'), findsWidgets);
    expect(find.textContaining('Demo'), findsWidgets);

    // El trabajo de hoy: se muestra vacío en vez de inventarse citas.
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Hoy no tienes citas'), findsOneWidget);

    // Navbar footer (sin drawer ni AppBar).
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    for (final String label in ['Inicio', 'Servicios', 'Movimientos', 'Más']) {
      expect(
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
        findsOneWidget,
      );
    }

    // Servicios: su trabajo, separado de su plata.
    await tester.tap(find.descendant(of: find.byType(AppNavBar), matching: find.text('Servicios')));
    await _settle(tester);
    expect(find.text('Mis servicios'), findsOneWidget);

    // Movimientos: lo que se le abonó y lo que se le consignó.
    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text('Movimientos')),
    );
    await _settle(tester);
    expect(find.text('Movimientos'), findsWidgets);

    // Más: el índice de lo suyo (perfil, cuentas, notificaciones).
    await tester.tap(find.descendant(of: find.byType(AppNavBar), matching: find.text('Más')));
    await _settle(tester);
    expect(find.text('Demo Empleado'), findsOneWidget);
    expect(find.text('Tus datos, tu foto y tu contraseña'), findsOneWidget);
  });

  testWidgets('Dueño: recorrido propio (panel, liquidar, equipo), no el del empleado',
      (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(AuthState(user: _owner()));
    await tester.pumpWidget(_app(
      home: const HomeShell(),
      auth: auth,
      branches: const [Branch(id: 'br-1', name: 'Sede Centro')],
      team: const [
        TeamMember(
          id: 'e-1',
          personName: 'Ana Ruiz',
          photoUrl: null,
          branchId: 'br-1',
          branchName: 'Sede Centro',
        ),
      ],
      balances: const [
        TeamBalance(
          employeeId: 'e-1',
          branchId: 'br-1',
          accrued: 450000,
          paid: 0,
          pending: 450000,
          currency: 'COP',
        ),
      ],
    ),);
    await _settle(tester);

    // Tabs del dueño, no los del empleado.
    for (final String label in ['Panel', 'Liquidar', 'Equipo', 'Perfil']) {
      expect(
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(find.descendant(of: find.byType(AppNavBar), matching: find.text('Citas')), findsNothing);

    // El panel abre con la decisión de plata: lo que hay por abonar.
    expect(find.text('Saldo a abonar'), findsOneWidget);
    expect(find.text(r'$ 450.000'), findsWidgets);

    // Liquidaciones: el colaborador con saldo y su acción.
    await tester.tap(find.descendant(of: find.byType(AppNavBar), matching: find.text('Liquidar')));
    await _settle(tester);
    expect(find.text('Total por confirmar'), findsOneWidget);
    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('Abonar aprobado'), findsOneWidget);

    // Confirmar es irreversible: exige confirmación explícita con el monto.
    await tester.tap(find.text('Abonar aprobado'));
    await _settle(tester);
    expect(find.textContaining('irreversible'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await _settle(tester);

    // Equipo: quién está y en qué sede.
    await tester.tap(find.descendant(of: find.byType(AppNavBar), matching: find.text('Equipo')));
    await _settle(tester);
    expect(find.text('Estado del equipo'), findsOneWidget);
    expect(find.text('Ana Ruiz'), findsOneWidget);
    expect(find.text('Sede Centro'), findsWidgets);
  });

  testWidgets('Menús: las pestañas salen de la configuración y los submenús no',
      (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(AuthState(user: _owner()));

    // Árbol como el que sirve /system/menus/me: un grupo sin ruta (encabezado),
    // un menú con submenús colgando, y una hoja normal.
    const List<MenuNode> tree = [
      MenuNode(
        id: 'g', code: 'NEG', name: 'Negocio', displayOrder: 1,
        children: [
          MenuNode(
            id: 'c', code: 'TENANT_COMPANY', name: 'Mi empresa',
            route: '/tenant/dashboard', icon: 'building-2', displayOrder: 1,
            children: [
              // Submenús: viven en el nav secundario de su padre, NO son pestañas.
              MenuNode(id: 's1', code: 'TENANT_SERVICES', name: 'Servicios',
                  route: '/tenant/servicios', displayOrder: 1, submenu: true,),
              MenuNode(id: 's2', code: 'TENANT_BRANCHES', name: 'Sedes',
                  route: '/tenant/sedes', displayOrder: 2, submenu: true,),
            ],
          ),
          MenuNode(id: 'l', code: 'TENANT_SETTLEMENTS', name: 'Liquidaciones',
              route: '/tenant/liquidaciones', icon: 'activity', displayOrder: 2,),
        ],
      ),
      MenuNode(id: 'p', code: 'TENANT_PROFILE', name: 'Mi perfil',
          route: '/tenant/profile', icon: 'user', displayOrder: 3,),
    ];

    await tester.pumpWidget(_app(home: const HomeShell(), auth: auth, menu: tree));
    await _settle(tester);

    // Las aserciones se acotan a la barra: "Sedes" o "Servicios" pueden
    // aparecer como contadores dentro del panel, y eso no es una pestaña.
    Finder tab(String label) =>
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label));

    // Lo que la configuración enciende, con SU nombre (no el cableado).
    expect(tab('Mi empresa'), findsOneWidget);
    expect(tab('Liquidaciones'), findsOneWidget);
    expect(tab('Mi perfil'), findsOneWidget);

    // Los submenús NO asoman como pestañas: su sitio es el nav de su padre.
    expect(tab('Servicios'), findsNothing);
    expect(tab('Sedes'), findsNothing);

    // Y el grupo sin ruta tampoco: es un encabezado, no un destino.
    expect(tab('Negocio'), findsNothing);

    // Las etiquetas cableadas quedaron atrás.
    expect(tab('Liquidar'), findsNothing);
    expect(tab('Equipo'), findsNothing);
  });

  testWidgets('Menús: el perfil no depende de la configuración', (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(AuthState(user: _owner()));

    // Árbol real de un dueño: sin TENANT_PROFILE y con el equipo metido como
    // submenú del dock de "Mi empresa" (que en el APK no tiene pantalla).
    const List<MenuNode> tree = [
      MenuNode(id: 'd', code: 'TENANT_DASHBOARD', name: 'Panel',
          route: '/tenant/dashboard', icon: 'activity', displayOrder: 1,),
      MenuNode(
        id: 'g', code: 'NEG', name: 'Negocio', displayOrder: 2,
        children: [
          MenuNode(id: 'c', code: 'TENANT_COMPANY', name: 'Mi empresa',
              route: '/tenant/mi-empresa', displayOrder: 1,
              children: [
                MenuNode(id: 'e', code: 'TENANT_EMPLOYEES', name: 'Empleados',
                    route: '/tenant/empleados', displayOrder: 1, submenu: true,),
              ],),
          MenuNode(id: 'l', code: 'TENANT_SETTLEMENTS', name: 'Liquidaciones',
              route: '/tenant/liquidaciones', icon: 'activity', displayOrder: 2,),
        ],
      ),
    ];

    await tester.pumpWidget(_app(home: const HomeShell(), auth: auth, menu: tree));
    await _settle(tester);

    Finder tab(String label) =>
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label));

    // Cerrar sesión y la huella viven en Perfil: no puede desaparecer porque
    // el menú de la web no lo declare.
    expect(tab('Perfil'), findsOneWidget);
    expect(tab('Panel'), findsOneWidget);
    expect(tab('Liquidaciones'), findsOneWidget);
  });

  testWidgets('Recurrencia: pide la huella sola al abrir, y deja reintentar', (tester) async {
    _phoneViewport(tester);
    // Sesión guardada y bloqueada por huella: el estado en el que se abre la
    // pantalla de recurrencia.
    final _FakeAuth auth = _FakeAuth(AuthState(lockedUser: _employee()));
    // El lector RECHAZA: así se comprueba lo automático y, además, que un fallo
    // no deja la pantalla dando vueltas volviendo a abrir el prompt.
    final _FakeBiometrics bio = _FakeBiometrics(accepts: false);

    await tester.pumpWidget(_app(home: const UnlockScreen(), auth: auth, biometrics: bio));
    await _settle(tester);

    // Lo importante: al abrir se pidió la huella sin que nadie tocara nada. Es
    // la razón de ser de esta pantalla — quien vuelve entra con el dedo puesto.
    expect(bio.calls, 1, reason: 'con la huella vinculada, la app debe pedirla al abrir');

    // Saluda a quien vuelve, por su nombre.
    expect(find.textContaining('Hola de nuevo'), findsOneWidget);
    expect(find.textContaining('Demo'), findsOneWidget);

    // Tras el rechazo NO se reintenta solo: quedaría un bucle del que no se
    // puede salir ni para pulsar la salida a credenciales.
    await _settle(tester);
    expect(bio.calls, 1, reason: 'un fallo no puede relanzar el lector por su cuenta');

    // Una sola acción principal, más la salida al formulario de siempre.
    expect(find.byType(FingerprintButton), findsOneWidget);
    expect(find.text('Entrar con usuario y contraseña'), findsOneWidget);

    // Y a mano, se puede volver a intentar.
    await tester.tap(find.byType(FingerprintButton));
    await _settle(tester);
    expect(bio.calls, 2);
  });

  testWidgets('Bienvenida: la salida a credenciales suelta el bloqueo', (tester) async {
    _phoneViewport(tester);
    final _FakeAuth auth = _FakeAuth(AuthState(lockedUser: _employee()));
    // Lector que rechaza: el intento automático de la pantalla falla y la
    // salida a credenciales tiene que seguir estando disponible. Es justo el
    // caso del dedo mojado o el sensor sucio.
    await tester.pumpWidget(
      _app(
        home: const UnlockScreen(),
        auth: auth,
        biometrics: _FakeBiometrics(accepts: false),
      ),
    );
    await _settle(tester);

    expect(auth.state.biometricLocked, isTrue);
    await tester.tap(find.text('Entrar con usuario y contraseña'));
    await _settle(tester);

    // Sin bloqueo, el router lleva al login. Nadie se queda encerrado por un
    // sensor que no responde.
    expect(auth.state.biometricLocked, isFalse);
  });
}
