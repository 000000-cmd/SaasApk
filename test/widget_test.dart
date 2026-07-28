import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/core/auth/auth_guard.dart';
import 'package:saas_app/core/auth/auth_models.dart';

AppUser _user(List<String> roles) =>
    AppUser(id: '1', username: 'u', roles: roles, kind: AppUser.kindFromRoles(roles));

void main() {
  group('Acceso al APK (dueño + empleados, no admin del sistema)', () {
    test('OWNER puede entrar', () {
      expect(AuthGuard.canAccessApp(_user(['OWNER'])), isTrue);
    });

    test('EMPLOYEE puede entrar', () {
      expect(AuthGuard.canAccessApp(_user(['EMPLOYEE'])), isTrue);
    });

    test('ADMIN del sistema NO puede entrar (usa la web)', () {
      expect(AuthGuard.canAccessApp(_user(['ADMIN'])), isFalse);
      expect(AuthGuard.canAccessApp(_user(['SYSTEM_ADMIN'])), isFalse);
    });

    test('Sin sesión no puede entrar', () {
      expect(AuthGuard.canAccessApp(null), isFalse);
    });
  });
}
