import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Escala tipográfica del sistema **Vertex** (idéntica a la web).
///
/// Doble familia a propósito:
///  - **Manrope** en titulares: geométrica y ligeramente condensada, da el aire
///    premium y estructurado de una herramienta profesional.
///  - **Inter** en cuerpo, etiquetas y captura de datos: legibilidad excepcional
///    en pantallas densas de cifras.
///
/// Los titulares llevan tracking negativo (presencia); las etiquetas pequeñas
/// van con tracking positivo y peso alto (visibles de un vistazo).
class AppTypography {
  AppTypography._();

  static TextStyle displayXl({Color? color}) => GoogleFonts.manrope(
        fontSize: 40, height: 48 / 40, fontWeight: FontWeight.w800, letterSpacing: -0.02 * 40, color: color,
      );

  static TextStyle headlineLg({Color? color}) => GoogleFonts.manrope(
        fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w700, letterSpacing: -0.01 * 28, color: color,
      );

  static TextStyle headlineMd({Color? color}) => GoogleFonts.manrope(
        fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w700, color: color,
      );

  static TextStyle titleMd({Color? color}) => GoogleFonts.manrope(
        fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w700, color: color,
      );

  static TextStyle bodyLg({Color? color}) => GoogleFonts.inter(
        fontSize: 18, height: 28 / 18, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle bodyMd({Color? color}) => GoogleFonts.inter(
        fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle bodySm({Color? color}) => GoogleFonts.inter(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle labelMd({Color? color}) => GoogleFonts.inter(
        fontSize: 14, height: 16 / 14, fontWeight: FontWeight.w600, letterSpacing: 0.02 * 14, color: color,
      );

  static TextStyle labelSm({Color? color}) => GoogleFonts.inter(
        fontSize: 12, height: 14 / 12, fontWeight: FontWeight.w700, letterSpacing: 0.05 * 12, color: color,
      );
}
