import 'package:flutter/services.dart';

/// Máscaras de entrada para documento y celular.
///
/// La idea es que el usuario vea el número agrupado mientras escribe, pero el
/// texto CRUDO siga siendo solo dígitos (el `.trim()` que envía el formulario
/// no arrastra espacios de la máscara: se limpian antes de enviar con
/// [digitsOnly]).
class InputMasks {
  InputMasks._();

  /// Número de documento agrupado de a tres DESDE LA DERECHA: `1.098.765.432`.
  ///
  /// Es como se lee una cédula en Colombia y como la tiene el usuario en la
  /// cabeza. Agrupar por la izquierda con tamaños fijos no sirve aquí: las
  /// cédulas van de 6 a 10 dígitos y los NIT de 9 a 10, así que el patrón
  /// depende del largo.
  static List<TextInputFormatter> document({int maxLength = 15}) => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
        const _ThousandsFormatter(),
      ];

  /// Fecha `dd/mm/aaaa` con las barras puestas al vuelo: se teclean 8 dígitos
  /// y nunca hay que escribir un separador. Es lo que hace cómodo llenarla a
  /// mano cuando no se quiere abrir el calendario.
  static List<TextInputFormatter> date() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
        const _GroupFormatter([2, 2, 4], separator: '/'),
      ];

  /// Celular colombiano: 10 dígitos agrupados `### ### ####`.
  static List<TextInputFormatter> phoneCo() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
        const _GroupFormatter([3, 3, 4]),
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

/// Agrupa de a tres desde la derecha con puntos: `1234567` → `1.234.567`.
class _ThousandsFormatter extends TextInputFormatter {
  const _ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final StringBuffer buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      // Un punto cada tres dígitos contando desde el final.
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    final String text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inserta un separador según un patrón de grupos (p. ej. [3,3,4] → "300 123 4567").
class _GroupFormatter extends TextInputFormatter {
  const _GroupFormatter(this.groups, {this.separator = ' '});
  final List<int> groups;
  final String separator;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    int i = 0;
    for (final g in groups) {
      if (i >= digits.length) break;
      if (i > 0) buf.write(separator);
      final end = (i + g).clamp(0, digits.length);
      buf.write(digits.substring(i, end));
      i = end;
    }
    // Dígitos sobrantes (si los hubiera) se anexan sin romper.
    if (i < digits.length) buf.write('$separator${digits.substring(i)}');
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
