/// Formato de dinero colombiano — espeja `formatCOP` del front web:
/// sin decimales y con punto de miles: `$ 1.250.000`.
String formatCOP(num value) {
  final bool negative = value < 0;
  final String digits = value.abs().round().toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return '${negative ? '-' : ''}\$ $out';
}
