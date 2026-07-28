import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Escala tipográfica del sistema "Luminous Aura" (idéntica a la web).
///
/// Doble familia a propósito:
///  - **Bricolage Grotesque** en titulares: sus curvas irregulares pero
///    refinadas espejan la fluidez del orb y dan el aire editorial.
///  - **Hanken Grotesk** en cuerpo y etiquetas: sans contemporánea, legible en
///    pantallas densas de datos.
///
/// Los display llevan tracking negativo (presencia); las etiquetas pequeñas
/// van con tracking positivo (claridad).
class AppTypography {
  AppTypography._();

  static TextStyle displayXl({Color? color}) => GoogleFonts.bricolageGrotesque(
        fontSize: 40, height: 48 / 40, fontWeight: FontWeight.w700, letterSpacing: -0.02 * 40, color: color,
      );

  static TextStyle headlineLg({Color? color}) => GoogleFonts.bricolageGrotesque(
        fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600, color: color,
      );

  static TextStyle headlineMd({Color? color}) => GoogleFonts.bricolageGrotesque(
        fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w600, color: color,
      );

  static TextStyle titleMd({Color? color}) => GoogleFonts.bricolageGrotesque(
        fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: color,
      );

  static TextStyle bodyLg({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 18, height: 28 / 18, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle bodyMd({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle bodySm({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: color,
      );

  static TextStyle labelMd({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, letterSpacing: 0.05 * 14, color: color,
      );

  static TextStyle labelSm({Color? color}) => GoogleFonts.hankenGrotesk(
        fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w700, letterSpacing: 0.08 * 11, color: color,
      );
}
