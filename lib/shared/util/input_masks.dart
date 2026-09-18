import 'package:flutter/services.dart';
import 'package:saas_app/shared/util/masks.dart';

/// Atajos de máscara para los campos de la app.
///
/// NO define ninguna máscara: elige una del estándar (`masks.dart`), que es el
/// mismo que usa la web. Antes esta clase traía su propio agrupador de miles y
/// su propio agrupador por patrón — dos implementaciones más de lo mismo, y
/// ambas mandaban el cursor al final del campo en cada tecla, así que corregir
/// un dígito en mitad de una cédula era imposible.
///
/// Se conserva como API porque es lo que llaman las pantallas y porque añade lo
/// que el estándar no puede saber: qué tope tiene ESTE campo y qué caracteres
/// no admite (una llave BREV es texto libre, pero nunca lleva espacios).
class InputMasks {
  InputMasks._();

  /// Número de documento agrupado de a tres desde la derecha: `1.098.765.432`.
  /// Se envía sin puntos (ver [digitsOnly]).
  static List<TextInputFormatter> document({int maxLength = 15}) => <TextInputFormatter>[
        LengthLimitingTextInputFormatter(maxLength),
        const MaskFormatter(MaskId.document),
      ];

  /// Fecha `dd/mm/aaaa` con las barras puestas al vuelo: se teclean 8 dígitos
  /// y nunca hay que escribir un separador.
  static List<TextInputFormatter> date() => <TextInputFormatter>[
        const MaskFormatter(MaskId.date),
      ];

  /// Celular colombiano: 10 dígitos agrupados `300 123 4567`.
  static List<TextInputFormatter> phoneCo() => <TextInputFormatter>[
        const MaskFormatter(MaskId.phone),
      ];

  /// Número de cuenta bancaria, agrupado de a cuatro para poder cotejarlo con
  /// la libreta sin contar dígitos con el dedo. Se envía sin espacios.
  ///
  /// El filtro a dígitos importa aunque el teclado sea numérico: el teclado es
  /// una SUGERENCIA, en Android se cambia a mano y pegar del portapapeles se lo
  /// salta siempre. Una letra dentro de un número de cuenta es plata que no
  /// llega.
  static List<TextInputFormatter> accountNumber() => <TextInputFormatter>[
        const MaskFormatter(MaskId.bankAccount),
      ];

  /// Llave BREV: se guarda LITERAL (puede ser celular, correo o documento), así
  /// que no se filtran caracteres. Lo único que se impide es el espacio, que
  /// nunca forma parte de una llave y sí es el typo más común al pegarla.
  static List<TextInputFormatter> brevKey() => <TextInputFormatter>[
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
        LengthLimitingTextInputFormatter(60),
      ];

  /// Nombre de persona: letras, espacios y los signos de los apellidos
  /// compuestos, con la inicial de cada palabra en mayúscula.
  static List<TextInputFormatter> personName({int maxLength = 40}) => <TextInputFormatter>[
        LengthLimitingTextInputFormatter(maxLength),
        const MaskFormatter(MaskId.name),
      ];

  /// Correo: minúsculas y sin espacios.
  static List<TextInputFormatter> email() => <TextInputFormatter>[
        const MaskFormatter(MaskId.email),
      ];

  /// Dinero en pesos, agrupado: `25.000`. Se envía sin puntos.
  static List<TextInputFormatter> money() => <TextInputFormatter>[
        const MaskFormatter(MaskId.money),
      ];

  /// Código de verificación de 6 dígitos.
  static List<TextInputFormatter> otp() => <TextInputFormatter>[
        const MaskFormatter(MaskId.otp),
      ];

  /// Texto corto y libre (el alias con el que reconoces una cuenta). Sin
  /// máscara a propósito: no tiene forma.
  static List<TextInputFormatter> shortText({int maxLength = 40}) => <TextInputFormatter>[
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Quita todo lo que no sea dígito (para enviar el valor limpio al backend).
  static String digitsOnly(String v) => v.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Utilidades de fecha para los campos escritos a mano.
class DateText {
  DateText._();

  /// `dd/mm/aaaa` → DateTime, o null si no es una fecha real.
  ///
  /// Valida de verdad: 31/02/2024 no existe, y `DateTime(2024, 2, 31)` en Dart
  /// no falla — se desborda a marzo. Por eso se comprueba que lo que sale sea
  /// lo que se escribió.
  static DateTime? parse(String input) {
    final digits = InputMasks.digitsOnly(input);
    if (digits.length != 8) return null;
    final int d = int.parse(digits.substring(0, 2));
    final int m = int.parse(digits.substring(2, 4));
    final int y = int.parse(digits.substring(4, 8));
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final DateTime parsed = DateTime(y, m, d);
    if (parsed.day != d || parsed.month != m || parsed.year != y) return null;
    return parsed;
  }

  /// DateTime → `dd/mm/aaaa`, que es lo que espera el campo.
  static String format(DateTime? date) {
    if (date == null) return '';
    final String d = date.day.toString().padLeft(2, '0');
    final String m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  /// Fecha larga en español para mostrar (no para editar): `4 de marzo de 1990`.
  static String long(DateTime? date) {
    if (date == null) return '';
    const List<String> meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${meses[date.month - 1]} de ${date.year}';
  }

  /// `aaaa-mm-dd`, que es lo que viaja al backend.
  static String iso(DateTime? date) {
    if (date == null) return '';
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }
}
