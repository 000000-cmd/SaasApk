import 'package:flutter/services.dart';

/// ESTÁNDAR DE MÁSCARAS — espejo exacto de
/// `SaasFront/src/app/shared/forms/core/masks.ts`.
///
/// La regla del proyecto: ante cada campo, la primera pregunta es "¿este dato
/// tiene forma?". Si la tiene, lleva máscara. Sólo el texto libre (una nota,
/// una descripción) se queda sin ella.
///
/// Los ids, las salidas y los casos de `checkMasks()` son LOS MISMOS que en la
/// web. Si alguien cambia una máscara en un lado y no en el otro, el check del
/// otro lado se cae — que es justo lo que se quiere: un celular no puede
/// escribirse distinto en el móvil que en el navegador.
///
/// Dos motores, porque hay dos clases de dato:
///   - PLANTILLA  (`patternMask`): la forma es fija (celular, fecha, placa).
///   - AGRUPACIÓN (`groupRight` / `groupLeft`): la forma crece con el dato
///     (documento, dinero, cuenta bancaria).
enum MaskId {
  phone,
  landline,
  document,
  docId,
  nit,
  integer,
  money,
  decimal,
  percent,
  date,
  time,
  bankAccount,
  card,
  plate,
  code,
  slug,
  name,
  email,
  url,
  otp,
}

class MaskSpec {
  const MaskSpec({
    required this.label,
    required this.format,
    required this.unformat,
    required this.keyboard,
    required this.maxLength,
    required this.placeholder,
    required this.pattern,
    required this.help,
  });

  /// Etiqueta humana.
  final String label;

  /// Texto crudo → texto mostrado. Idempotente: format(format(x)) == format(x).
  final String Function(String) format;

  /// Texto mostrado → valor a guardar.
  ///
  /// OJO: no todas guardan en crudo. El celular se guarda CON los espacios
  /// porque así está en la base; el documento se guarda sin puntos porque los
  /// puntos no son parte del número. Cambiarlo no es cosmético: rompe datos.
  final String Function(String) unformat;

  /// El teclado que debe salir. Equivale al `inputMode` de la web.
  final TextInputType keyboard;

  /// Tope de caracteres del texto YA enmascarado.
  final int maxLength;
  final String placeholder;

  /// Qué se considera un valor completo y válido (sobre el texto mostrado).
  final RegExp pattern;

  /// Mensaje cuando `pattern` no casa.
  final String help;
}

// ---------------------------------------------------------------------------
// Motores
// ---------------------------------------------------------------------------

/// Plantilla de posiciones fijas. `0`=dígito, `A`=letra, `*`=alfanumérico;
/// cualquier otro carácter es literal y se inserta solo.
///
/// Se consume el crudo carácter a carácter y se descarta lo que no encaje en el
/// hueco actual. Pegar "(300) 123-4567" en `000 000 0000` da "300 123 4567":
/// los literales ajenos se caen solos.
String patternMask(String pattern, String raw) {
  final String src = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final StringBuffer out = StringBuffer();
  int i = 0;
  for (final String slot in pattern.split('')) {
    if (i >= src.length) break;
    if (slot == '0' || slot == 'A' || slot == '*') {
      while (i < src.length && !_fits(slot, src[i])) {
        i++;
      }
      if (i >= src.length) break;
      out.write(slot == 'A' ? src[i].toUpperCase() : src[i]);
      i++;
    } else {
      out.write(slot);
    }
  }
  // Un literal colgando al final ("300 ") se ve como un error de escritura.
  return out.toString().replaceAll(RegExp(r'[^0-9A-Za-z]+$'), '');
}

bool _fits(String slot, String ch) {
  if (slot == '0') return RegExp(r'[0-9]').hasMatch(ch);
  if (slot == 'A') return RegExp(r'[A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(ch);
  return RegExp(r'[0-9A-Za-zÁÉÍÓÚÑáéíóúñ]').hasMatch(ch);
}

/// Agrupa DESDE LA DERECHA: es como se leen los miles. `1234567 → 1.234.567`.
String groupRight(String input, {int size = 3, String sep = '.'}) {
  final String d = input.replaceAll(RegExp(r'\D+'), '');
  if (d.isEmpty) return '';
  final List<String> parts = <String>[];
  for (int end = d.length; end > 0; end -= size) {
    final int start = end - size < 0 ? 0 : end - size;
    parts.insert(0, d.substring(start, end));
  }
  return parts.join(sep);
}

/// Agrupa DESDE LA IZQUIERDA: es como se leen cuentas y tarjetas.
String groupLeft(String input, {int size = 4, String sep = ' '}) {
  final String d = input.replaceAll(RegExp(r'\D+'), '');
  if (d.isEmpty) return '';
  final List<String> parts = <String>[];
  for (int i = 0; i < d.length; i += size) {
    parts.add(d.substring(i, i + size > d.length ? d.length : i + size));
  }
  return parts.join(sep);
}

String _digits(String s) => s.replaceAll(RegExp(r'\D+'), '');
String _asIs(String s) => s;

// ---------------------------------------------------------------------------
// La tabla
// ---------------------------------------------------------------------------

final Map<MaskId, MaskSpec> kMasks = <MaskId, MaskSpec>{
  // --- Contacto -----------------------------------------------------------
  MaskId.phone: MaskSpec(
    label: 'Celular',
    format: (String r) => patternMask('000 000 0000', r),
    unformat: _asIs, // se guarda con espacios (ver MaskSpec)
    keyboard: TextInputType.phone,
    maxLength: 12,
    placeholder: '300 123 4567',
    pattern: RegExp(r'^3\d{2} \d{3} \d{4}$'),
    help: 'Celular de 10 dígitos que empieza por 3.',
  ),
  MaskId.landline: MaskSpec(
    label: 'Teléfono fijo',
    format: (String r) => patternMask('000 000 0000', r),
    unformat: _asIs,
    keyboard: TextInputType.phone,
    maxLength: 12,
    placeholder: '601 234 5678',
    pattern: RegExp(r'^\d{3} \d{3} \d{4}$'),
    help: 'Teléfono fijo de 10 dígitos con indicativo.',
  ),
  MaskId.email: MaskSpec(
    label: 'Correo',
    // Sin plantilla, pero con máscara: minúsculas y sin espacios. Un correo con
    // una mayúscula de más es la causa número uno de "mi cuenta no existe".
    format: (String r) => r.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
    unformat: _asIs,
    keyboard: TextInputType.emailAddress,
    maxLength: 120,
    placeholder: 'correo@dominio.com',
    pattern: RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$'),
    help: 'Escribe un correo válido.',
  ),
  MaskId.url: MaskSpec(
    label: 'Enlace',
    format: (String r) => r.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
    unformat: _asIs,
    keyboard: TextInputType.url,
    maxLength: 300,
    placeholder: 'https://ejemplo.com',
    pattern: RegExp(r'^https?:\/\/[^\s.]+\.[^\s]{2,}$'),
    help: 'El enlace debe empezar por http:// o https://',
  ),

  // --- Identificación -----------------------------------------------------
  MaskId.document: MaskSpec(
    label: 'Número de documento',
    format: (String r) => groupRight(_digits(r)),
    unformat: _digits, // se guarda limpio: los puntos no son el número
    keyboard: TextInputType.number,
    maxLength: 15,
    placeholder: '1.234.567.890',
    pattern: RegExp(r'^\d{1,3}(\.\d{3})*$'),
    help: 'Solo números.',
  ),
  MaskId.docId: MaskSpec(
    label: 'Número de documento (cualquier tipo)',
    // Alfanumérico Y EN MAYÚSCULAS, no sólo dígitos. El catálogo del sistema
    // incluye pasaporte y cédula de extranjería, que llevan letras: forzar
    // dígitos aquí borraría media identificación en silencio.
    //
    // La otra máscara, `document`, agrupa de a tres con puntos y sí es sólo
    // numérica: se usa donde el tipo está garantizado.
    format: (String r) => r.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), ''),
    unformat: _asIs,
    keyboard: TextInputType.text,
    maxLength: 20,
    placeholder: '1234567890',
    pattern: RegExp(r'^[A-Z0-9]{4,20}$'),
    help: 'Sin puntos ni espacios. Los pasaportes pueden llevar letras.',
  ),
  MaskId.nit: MaskSpec(
    label: 'NIT',
    // El dígito de verificación va tras un guion y NO se agrupa: es otro dato
    // pegado al mismo campo.
    format: (String r) {
      final String d0 = _digits(r);
      final String d = d0.length > 10 ? d0.substring(0, 10) : d0;
      if (d.length <= 9) return groupRight(d);
      return '${groupRight(d.substring(0, 9))}-${d.substring(9, 10)}';
    },
    unformat: _digits,
    keyboard: TextInputType.number,
    maxLength: 15,
    placeholder: '900.123.456-7',
    pattern: RegExp(r'^\d{1,3}(\.\d{3})*(-\d)?$'),
    help: 'NIT con su dígito de verificación.',
  ),
  MaskId.plate: MaskSpec(
    label: 'Placa',
    format: (String r) => patternMask('AAA000', r),
    unformat: _asIs,
    keyboard: TextInputType.text,
    maxLength: 6,
    placeholder: 'ABC123',
    pattern: RegExp(r'^[A-Z]{3}\d{3}$'),
    help: 'Tres letras y tres números.',
  ),

  // --- Dinero y números ---------------------------------------------------
  MaskId.money: MaskSpec(
    label: 'Dinero (COP)',
    // Sin decimales: el proyecto opera en pesos y nadie cobra centavos.
    format: (String r) => groupRight(_digits(r)),
    unformat: _digits,
    keyboard: TextInputType.number,
    maxLength: 15,
    placeholder: '0',
    pattern: RegExp(r'^\d{1,3}(\.\d{3})*$'),
    help: 'Solo números.',
  ),
  MaskId.integer: MaskSpec(
    label: 'Número entero',
    format: (String r) => groupRight(_digits(r)),
    unformat: _digits,
    keyboard: TextInputType.number,
    maxLength: 15,
    placeholder: '0',
    pattern: RegExp(r'^\d{1,3}(\.\d{3})*$'),
    help: 'Solo números enteros.',
  ),
  MaskId.decimal: MaskSpec(
    label: 'Número con decimales',
    // Coma decimal: es la convención local, y el punto ya está tomado por los
    // miles. Un solo separador y como mucho dos decimales.
    format: (String r) {
      final String s = r.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll('.', ',');
      final List<String> trozos = s.split(',');
      final String entero = groupRight(trozos[0]);
      if (trozos.length == 1) return entero;
      String dec = trozos.sublist(1).join('');
      if (dec.length > 2) dec = dec.substring(0, 2);
      return '${entero.isEmpty ? '0' : entero},$dec';
    },
    unformat: (String s) => s.replaceAll('.', '').replaceFirst(',', '.'),
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    maxLength: 18,
    placeholder: '0,00',
    pattern: RegExp(r'^\d{1,3}(\.\d{3})*(,\d{1,2})?$'),
    help: 'Usa la coma para los decimales.',
  ),
  MaskId.percent: MaskSpec(
    label: 'Porcentaje',
    format: (String r) {
      final String s = r.replaceAll(RegExp(r'[^\d.,]'), '').replaceAll('.', ',');
      final List<String> trozos = s.split(',');
      if (trozos[0].isEmpty && trozos.length == 1) return '';
      // Un porcentaje por encima de 100 casi siempre es un dedo de más.
      final int n = int.tryParse(trozos[0].replaceAll(RegExp(r'\D+'), '')) ?? 0;
      final int e = n > 100 ? 100 : n;
      if (trozos.length == 1) return '$e';
      String dec = trozos.sublist(1).join('');
      if (dec.length > 2) dec = dec.substring(0, 2);
      return '$e,$dec';
    },
    unformat: (String s) => s.replaceFirst(',', '.'),
    keyboard: const TextInputType.numberWithOptions(decimal: true),
    maxLength: 6,
    placeholder: '0',
    pattern: RegExp(r'^(100|\d{1,2})(,\d{1,2})?$'),
    help: 'Entre 0 y 100.',
  ),

  // --- Bancario -----------------------------------------------------------
  MaskId.bankAccount: MaskSpec(
    label: 'Número de cuenta',
    format: (String r) {
      final String d = _digits(r);
      return groupLeft(d.length > 20 ? d.substring(0, 20) : d);
    },
    unformat: _digits,
    keyboard: TextInputType.number,
    maxLength: 24,
    placeholder: '1234 5678 9012',
    pattern: RegExp(r'^\d{4}( \d{1,4})*$'),
    help: 'Solo los números de la cuenta.',
  ),
  MaskId.card: MaskSpec(
    label: 'Tarjeta',
    format: (String r) {
      final String d = _digits(r);
      return groupLeft(d.length > 16 ? d.substring(0, 16) : d);
    },
    unformat: _digits,
    keyboard: TextInputType.number,
    maxLength: 19,
    placeholder: '4111 1111 1111 1111',
    pattern: RegExp(r'^\d{4} \d{4} \d{4} \d{4}$'),
    help: 'Los 16 dígitos de la tarjeta.',
  ),

  // --- Tiempo -------------------------------------------------------------
  MaskId.date: MaskSpec(
    label: 'Fecha',
    format: (String r) => patternMask('00/00/0000', r),
    unformat: (String s) {
      final RegExpMatch? m = RegExp(r'^(\d{2})\/(\d{2})\/(\d{4})$').firstMatch(s);
      return m == null ? s : '${m.group(3)}-${m.group(2)}-${m.group(1)}'; // ISO
    },
    keyboard: TextInputType.number,
    maxLength: 10,
    placeholder: 'dd/mm/aaaa',
    pattern: RegExp(r'^(0[1-9]|[12]\d|3[01])\/(0[1-9]|1[0-2])\/\d{4}$'),
    help: 'Formato dd/mm/aaaa.',
  ),
  MaskId.time: MaskSpec(
    label: 'Hora',
    format: (String r) => patternMask('00:00', r),
    unformat: _asIs,
    keyboard: TextInputType.number,
    maxLength: 5,
    placeholder: 'hh:mm',
    pattern: RegExp(r'^([01]\d|2[0-3]):[0-5]\d$'),
    help: 'Formato de 24 horas (hh:mm).',
  ),
  MaskId.otp: MaskSpec(
    label: 'Código de verificación',
    format: (String r) {
      final String d = _digits(r);
      return d.length > 6 ? d.substring(0, 6) : d;
    },
    unformat: _asIs,
    keyboard: TextInputType.number,
    maxLength: 6,
    placeholder: '000000',
    pattern: RegExp(r'^\d{6}$'),
    help: 'Los 6 dígitos que te enviamos.',
  ),

  // --- Texto con forma ----------------------------------------------------
  MaskId.code: MaskSpec(
    label: 'Código',
    format: (String r) => r
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+'), ''),
    unformat: _asIs,
    keyboard: TextInputType.text,
    maxLength: 80,
    placeholder: 'CODIGO_EJEMPLO',
    pattern: RegExp(r'^[A-Z][A-Z0-9_]*$'),
    help: 'Mayúsculas, números y guion bajo.',
  ),
  MaskId.slug: MaskSpec(
    label: 'Identificador de URL',
    format: (String r) => _sinTildes(r.toLowerCase())
        .replaceAll(RegExp(r'[^a-z0-9-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+'), ''),
    unformat: _asIs,
    keyboard: TextInputType.text,
    maxLength: 60,
    placeholder: 'mi-negocio',
    pattern: RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'),
    help: 'Minúsculas, números y guiones.',
  ),
  MaskId.name: MaskSpec(
    label: 'Nombre propio',
    // Inicial en mayúscula por palabra, sin espacios dobles. No es cosmética:
    // los nombres acaban en recibos, correos y en la app del empleado.
    format: (String r) {
      final String limpio = r
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .replaceAll(RegExp(r"[^\p{L}\s'´-]", unicode: true), '');
      return limpio.replaceAllMapped(
        RegExp(r"(^|[\s'´-])(\p{L})", unicode: true),
        (Match m) => '${m.group(1)}${m.group(2)!.toUpperCase()}',
      );
    },
    unformat: (String s) => s.trim(),
    keyboard: TextInputType.name,
    maxLength: 80,
    placeholder: 'Nombre Apellido',
    pattern: RegExp(r"^\p{L}[\p{L}\s'´-]*$", unicode: true),
    help: 'Solo letras.',
  ),
};

/// Dart no trae normalización Unicode, así que la tabla es explícita. Cubre lo
/// que aparece de verdad en nombres de negocio en español.
String _sinTildes(String s) {
  const Map<String, String> tabla = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final StringBuffer out = StringBuffer();
  for (final String ch in s.split('')) {
    out.write(tabla[ch] ?? ch);
  }
  return out.toString();
}

/// Aplica una máscara por id. Sin id, devuelve el texto tal cual (texto libre).
String applyMask(MaskId? id, String raw) {
  if (id == null) return raw;
  return kMasks[id]?.format(raw) ?? raw;
}

/// Deshace la máscara para obtener lo que se guarda.
String stripMask(MaskId? id, String shown) {
  if (id == null) return shown;
  return kMasks[id]?.unformat(shown) ?? shown;
}

// ---------------------------------------------------------------------------
// Integración con Flutter
// ---------------------------------------------------------------------------

/// `TextInputFormatter` que aplica una máscara del estándar conservando el
/// cursor donde estaba.
///
/// El detalle que hace o rompe una máscara: si al insertar un punto de miles el
/// cursor salta al final, escribir un número largo es imposible. Se cuenta
/// cuántos caracteres "de dato" (no separadores) había antes del cursor y se
/// recoloca detrás del mismo número en el texto nuevo.
class MaskFormatter extends TextInputFormatter {
  const MaskFormatter(this.id);

  final MaskId id;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final String masked = applyMask(id, newValue.text);
    if (masked == newValue.text) return newValue;

    final int caret = newValue.selection.baseOffset < 0
        ? newValue.text.length
        : newValue.selection.baseOffset;
    final int datosAntes = _contarDatos(newValue.text.substring(0, caret));

    int pos = masked.length;
    if (datosAntes == 0) {
      pos = 0;
    } else {
      int vistos = 0;
      for (int i = 0; i < masked.length; i++) {
        if (_esDato(masked[i])) vistos++;
        if (vistos >= datosAntes) {
          pos = i + 1;
          break;
        }
      }
    }
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: pos > masked.length ? masked.length : pos),
    );
  }
}

final RegExp _reDato = RegExp(r'[0-9\p{L}]', unicode: true);
bool _esDato(String ch) => _reDato.hasMatch(ch);
int _contarDatos(String s) => _reDato.allMatches(s).length;

// ---------------------------------------------------------------------------
// Comprobación
// ---------------------------------------------------------------------------

/// Los MISMOS casos que `checkMasks()` en
/// `SaasFront/src/app/shared/forms/core/masks.ts`. Si cambias uno aquí,
/// cámbialo allí: es lo único que mantiene los dos lados diciendo lo mismo.
void checkMasks() {
  void eq(String got, String want, String what) {
    if (got != want) {
      throw StateError('$what: esperaba "$want", llegó "$got"');
    }
  }

  eq(applyMask(MaskId.phone, '3001234567'), '300 123 4567', 'phone');
  eq(applyMask(MaskId.phone, '(300) 123-4567'), '300 123 4567', 'phone pegado');
  eq(applyMask(MaskId.phone, '300'), '300', 'phone parcial sin literal colgando');
  eq(applyMask(MaskId.document, '1234567890'), '1.234.567.890', 'document');
  eq(applyMask(MaskId.document, '123'), '123', 'document corto');
  eq(applyMask(MaskId.docId, '1098765432'), '1098765432', 'docId numérico');
  eq(applyMask(MaskId.docId, 'ab-12 34.'), 'AB1234', 'docId alfanumérico en mayúsculas');
  eq(applyMask(MaskId.nit, '9001234567'), '900.123.456-7', 'nit con DV');
  eq(applyMask(MaskId.nit, '900123456'), '900.123.456', 'nit sin DV');
  eq(applyMask(MaskId.money, '25000'), '25.000', 'money');
  eq(applyMask(MaskId.decimal, '1234,567'), '1.234,56', 'decimal recorta a 2');
  eq(applyMask(MaskId.decimal, '1234'), '1.234', 'decimal entero');
  eq(applyMask(MaskId.percent, '150'), '100', 'percent tope');
  eq(applyMask(MaskId.percent, '12,5'), '12,5', 'percent con coma');
  eq(applyMask(MaskId.bankAccount, '123456789012'), '1234 5678 9012', 'bankAccount');
  eq(applyMask(MaskId.card, '4111111111111111'), '4111 1111 1111 1111', 'card');
  eq(applyMask(MaskId.date, '01012026'), '01/01/2026', 'date');
  eq(applyMask(MaskId.time, '0930'), '09:30', 'time');
  eq(applyMask(MaskId.plate, 'abc123'), 'ABC123', 'plate mayúsculas');
  eq(applyMask(MaskId.code, 'tipo doc'), 'TIPO_DOC', 'code');
  eq(applyMask(MaskId.slug, 'Mi Negocio Ñ'), 'mi-negocio-n', 'slug sin tildes');
  eq(applyMask(MaskId.name, 'juan  carlos pérez'), 'Juan Carlos Pérez', 'name');
  eq(applyMask(MaskId.email, ' Correo@Dominio.COM '), 'correo@dominio.com', 'email');
  eq(applyMask(MaskId.otp, 'a1b2c3d4'), '1234', 'otp solo dígitos');

  // Idempotencia: volver a enmascarar lo ya enmascarado no puede cambiarlo.
  for (final MaskId id in MaskId.values) {
    final String una = applyMask(id, kMasks[id]!.placeholder);
    eq(applyMask(id, una), una, 'idempotencia de $id');
  }

  // Lo que se guarda.
  eq(stripMask(MaskId.document, '1.234.567.890'), '1234567890', 'document se guarda limpio');
  eq(stripMask(MaskId.phone, '300 123 4567'), '300 123 4567', 'phone se guarda con espacios');
  eq(stripMask(MaskId.date, '05/03/2026'), '2026-03-05', 'date se guarda en ISO');
  eq(stripMask(MaskId.decimal, '1.234,56'), '1234.56', 'decimal se guarda con punto');
}
