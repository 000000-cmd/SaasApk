import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saas_app/shared/util/input_masks.dart';

/// Aplica una cadena de formateadores como lo haría el campo de texto.
String _apply(List<TextInputFormatter> formatters, String input) {
  TextEditingValue value = TextEditingValue(
    text: input,
    selection: TextSelection.collapsed(offset: input.length),
  );
  for (final f in formatters) {
    value = f.formatEditUpdate(const TextEditingValue(), value);
  }
  return value.text;
}

void main() {
  group('Documento', () {
    test('agrupa de a tres desde la DERECHA', () {
      expect(_apply(InputMasks.document(), '1098765432'), '1.098.765.432');
      expect(_apply(InputMasks.document(), '900123456'), '900.123.456');
      // Cédulas cortas: el primer grupo queda incompleto, no el último.
      expect(_apply(InputMasks.document(), '12345'), '12.345');
      expect(_apply(InputMasks.document(), '123'), '123');
    });

    test('ignora lo que no sea dígito y no revienta vacío', () {
      expect(_apply(InputMasks.document(), 'abc'), '');
      expect(_apply(InputMasks.document(), ''), '');
    });

    test('digitsOnly devuelve lo que viaja al backend', () {
      expect(InputMasks.digitsOnly('1.098.765.432'), '1098765432');
    });
  });

  group('Fecha', () {
    test('pone las barras sola mientras se teclea', () {
      expect(_apply(InputMasks.date(), '0'), '0');
      expect(_apply(InputMasks.date(), '04'), '04');
      expect(_apply(InputMasks.date(), '043'), '04/3');
      expect(_apply(InputMasks.date(), '04031990'), '04/03/1990');
    });

    test('parse acepta una fecha real', () {
      expect(DateText.parse('04/03/1990'), DateTime(1990, 3, 4));
    });

    test('parse RECHAZA una fecha que no existe', () {
      // El caso importante: DateTime(2023, 2, 31) en Dart NO falla, se desborda
      // al 3 de marzo. Sin la comprobación, el 31 de febrero pasaría por válido.
      expect(DateText.parse('31/02/2023'), isNull);
      expect(DateText.parse('31/04/2024'), isNull);
      expect(DateText.parse('32/01/2024'), isNull);
      expect(DateText.parse('01/13/2024'), isNull);
    });

    test('parse acepta el 29 de febrero solo en año bisiesto', () {
      expect(DateText.parse('29/02/2024'), DateTime(2024, 2, 29));
      expect(DateText.parse('29/02/2023'), isNull);
    });

    test('parse rechaza lo incompleto', () {
      expect(DateText.parse('04/03'), isNull);
      expect(DateText.parse(''), isNull);
    });

    test('formatos de salida', () {
      final d = DateTime(1990, 3, 4);
      expect(DateText.format(d), '04/03/1990');
      expect(DateText.long(d), '4 de marzo de 1990');
      expect(DateText.iso(d), '1990-03-04');
      expect(DateText.format(null), '');
      expect(DateText.long(null), '');
    });
  });
}
