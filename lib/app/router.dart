import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/version/version_gate.dart';
import 'package:saas_app/features/auth/login_screen.dart';
import 'package:saas_app/features/auth/unlock_screen.dart';
import 'package:saas_app/features/employee/employee_onboarding_screen.dart';
import 'package:saas_app/features/home/home_shell.dart';
import 'package:saas_app/features/splash/splash_screen.dart';
import 'package:saas_app/features/update/update_required_screen.dart';

/// Router con guard de sesión y rol. Mientras [AuthState.initializing] se queda
/// en /splash; sin sesión válida va a /login; con sesión (dueño/empleado) a /home.
final routerProvider = Provider<GoRouter>((ref) {
  final ValueNotifier<int> refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.listen(versionGateProvider, (_, __) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final AuthState auth = ref.read(authControllerProvider);
      final String loc = state.matchedLocation;

      if (auth.initializing) return loc == '/splash' ? null : '/splash';
      // Version distinta a la vigente: bloquear TODO (incluso el login) hasta
      // actualizar. El chequeo es publico, asi que aplica antes de la sesion.
      if (ref.read(versionGateProvider).updateRequired) {
        return loc == '/update-required' ? null : '/update-required';
      }
      // Sesion guardada con huella activa: pantalla de bienvenida, no el
      // formulario. La huella la pide el usuario desde ahi, no la app sola.
      if (auth.biometricLocked) return loc == '/unlock' ? null : '/unlock';
      if (!auth.isAuthenticated) return loc == '/login' ? null : '/login';
      // Empleado en primer ingreso: completar perfil antes de operar.
      if (auth.needsOnboarding) {
        return loc == '/employee-onboarding' ? null : '/employee-onboarding';
      }
      if (loc == '/login' ||
          loc == '/unlock' ||
          loc == '/splash' ||
          loc == '/employee-onboarding' ||
          loc == '/update-required') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/unlock', builder: (_, __) => const UnlockScreen()),
      GoRoute(path: '/employee-onboarding', builder: (_, __) => const EmployeeOnboardingScreen()),
      GoRoute(path: '/update-required', builder: (_, __) => const UpdateRequiredScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});
