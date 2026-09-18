import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/core/notifications/inbox_repository.dart';

/// Lo que de verdad puede romperse al tocar la bandeja: leer el JSON del backend
/// y limpiar el HTML. Lo demás de la pantalla es composición de widgets.
void main() {
  group('InboxItem', () {
    test('sin readAt es no leída; con readAt, leída', () {
      final sinLeer = InboxItem.fromJson(<String, dynamic>{
        'id': 'a',
        'body': 'hola',
        'createdDate': '2026-07-30T10:00:00',
      });
      expect(sinLeer.unread, isTrue);

      final leida = InboxItem.fromJson(<String, dynamic>{
        'id': 'b',
        'body': 'hola',
        'createdDate': '2026-07-30T10:00:00',
        'readAt': '2026-07-30T11:00:00',
      });
      expect(leida.unread, isFalse);
    });

    test('el título puede no venir: la clave se omite cuando es nula', () {
      final n = InboxItem.fromJson(<String, dynamic>{
        'id': 'c',
        'body': 'x',
        'createdDate': '2026-07-30T10:00:00',
      });
      expect(n.title, isNull);
    });

    test('plainBody quita el HTML de una plantilla de correo', () {
      final n = InboxItem.fromJson(<String, dynamic>{
        'id': 'd',
        'body': '<div><p>Hola, <b>Camila</b>.</p>\n<p>Tu código es 123456</p></div>',
        'createdDate': '2026-07-30T10:00:00',
      });
      expect(n.plainBody, 'Hola, Camila . Tu código es 123456');
      expect(n.plainBody.contains('<'), isFalse);
    });

    test('un cuerpo vacío no revienta', () {
      final n = InboxItem.fromJson(<String, dynamic>{
        'id': 'e',
        'createdDate': '2026-07-30T10:00:00',
      });
      expect(n.body, '');
      expect(n.plainBody, '');
    });
  });
}
