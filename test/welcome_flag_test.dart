import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/core/auth/auth_models.dart';

/// El tour de bienvenida se gobierna por el INDICADOR DEL REGISTRO
/// (app_user.IsFirstLogin), no por una marca en el dispositivo: así no
/// reaparece al reinstalar la app ni al entrar desde otro teléfono.
void main() {
  group('Indicador de primer ingreso', () {
    test('en 1 el usuario debe ver la bienvenida', () {
      final u = AppUser.fromJson({
        'id': '1', 'username': 'u', 'roleCodes': ['EMPLOYEE'], 'isFirstLogin': true,
      });
      expect(u.isFirstLogin, isTrue);
    });

    test('en 0 NO se muestra la bienvenida', () {
      final u = AppUser.fromJson({
        'id': '1', 'username': 'u', 'roleCodes': ['EMPLOYEE'], 'isFirstLogin': false,
      });
      expect(u.isFirstLogin, isFalse);
    });

    test('si el campo no viene, se asume ya vista (no molestar)', () {
      final u = AppUser.fromJson({'id': '1', 'username': 'u', 'roleCodes': ['OWNER']});
      expect(u.isFirstLogin, isFalse);
    });

    test('el indicador sobrevive al guardar/restaurar la sesión', () {
      final u = AppUser.fromJson({
        'id': '1', 'username': 'u', 'roleCodes': ['EMPLOYEE'], 'isFirstLogin': true,
      });
      expect(AppUser.decode(u.encode()).isFirstLogin, isTrue);
    });

    test('marcarla vista apaga el indicador', () {
      final u = AppUser.fromJson({
        'id': '1', 'username': 'u', 'roleCodes': ['EMPLOYEE'], 'isFirstLogin': true,
      });
      expect(u.copyWith(isFirstLogin: false).isFirstLogin, isFalse);
    });
  });
}
