import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/shared/util/masks.dart';

/// El estándar de máscaras tiene que decir lo mismo aquí que en la web. Este
/// test corre EXACTAMENTE los mismos casos que `checkMasks()` de
/// `SaasFront/src/app/shared/forms/core/masks.ts`.
void main() {
  test('las máscaras coinciden con el estándar de la web', () {
    checkMasks();
  });

  test('el formatter conserva el cursor al insertar separadores', () {
    const MaskFormatter f = MaskFormatter(MaskId.document);
    // Escribiendo "1234" el cuarto dígito mete un punto: 1.234. El cursor debe
    // quedar detrás del 4 (posición 5), no al principio ni desplazado.
    final r = f.formatEditUpdate(
      const TextEditingValue(text: '123'),
      const TextEditingValue(
        text: '1234',
        selection: TextSelection(baseOffset: 4, extentOffset: 4),
      ),
    );
    expect(r.text, '1.234');
    expect(r.selection.baseOffset, 5);
  });
}
