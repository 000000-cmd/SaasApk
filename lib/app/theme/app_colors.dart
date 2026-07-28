import 'package:flutter/material.dart';

/// Paleta del design system "Luminous Aura" (misma que la web tras el refactor).
///
/// Los valores son los tokens Material-3 exactos del sistema de diseño: el
/// morado de marca sale del orb de la mascota y manda en acciones, progreso y
/// presencia. Las pantallas NO deben hardcodear colores: todo sale de aquí o
/// del [ThemeData].
class AppColors {
  AppColors._();

  // ---- Primary (morado de marca) ----
  static const Color primary = Color(0xFF8204BE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF9D34D9);
  static const Color onPrimaryContainer = Color(0xFFFAE6FF);
  static const Color primaryFixed = Color(0xFFF5D9FF);
  static const Color primaryFixedDim = Color(0xFFE6B4FF);
  static const Color onPrimaryFixed = Color(0xFF30004A);
  static const Color onPrimaryFixedVariant = Color(0xFF7000A6);
  static const Color inversePrimary = Color(0xFFE6B4FF);
  static const Color surfaceTint = Color(0xFF8F21CB);

  // ---- Secondary / tertiary (grafito + lavanda) ----
  static const Color secondary = Color(0xFF5F5E64);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE1DEE5);
  static const Color onSecondaryContainer = Color(0xFF636268);
  static const Color secondaryFixed = Color(0xFFE4E1E8);
  static const Color secondaryFixedDim = Color(0xFFC8C5CC);
  static const Color onSecondaryFixed = Color(0xFF1B1B20);
  static const Color onSecondaryFixedVariant = Color(0xFF47464C);
  static const Color tertiary = Color(0xFF575062);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF70687B);
  static const Color onTertiaryContainer = Color(0xFFF4E9FF);
  static const Color tertiaryFixed = Color(0xFFE9DEF5);
  static const Color tertiaryFixedDim = Color(0xFFCDC2D9);
  static const Color onTertiaryFixed = Color(0xFF1E1929);
  static const Color onTertiaryFixedVariant = Color(0xFF4A4456);

  // ---- Superficies (light) ----
  static const Color background = Color(0xFFF8F9FA);
  static const Color onBackground = Color(0xFF191C1D);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceBright = Color(0xFFF8F9FA);
  static const Color surfaceDim = Color(0xFFD9DADB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F4F5);
  static const Color surfaceContainer = Color(0xFFEDEEEF);
  static const Color surfaceContainerHigh = Color(0xFFE7E8E9);
  static const Color surfaceContainerHighest = Color(0xFFE1E3E4);
  static const Color surfaceVariant = Color(0xFFE1E3E4);
  static const Color onSurface = Color(0xFF191C1D);
  static const Color onSurfaceVariant = Color(0xFF4E4353);
  static const Color inverseSurface = Color(0xFF2E3132);
  static const Color inverseOnSurface = Color(0xFFF0F1F2);
  static const Color outline = Color(0xFF807384);
  static const Color outlineVariant = Color(0xFFD1C1D5);

  // ---- Superficies (dark, estándar M3 sobre el mismo morado) ----
  static const Color backgroundDark = Color(0xFF131215);
  static const Color surfaceDarkTone = Color(0xFF131215);
  static const Color surfaceContainerLowestDark = Color(0xFF0E0D10);
  static const Color surfaceContainerLowDark = Color(0xFF1C1B1F);
  static const Color surfaceContainerDark = Color(0xFF201F23);
  static const Color surfaceContainerHighDark = Color(0xFF2B292E);
  static const Color surfaceContainerHighestDark = Color(0xFF363438);
  static const Color onSurfaceDark = Color(0xFFE6E1E6);
  static const Color onSurfaceVariantDark = Color(0xFFCFC3D4);
  static const Color outlineDark = Color(0xFF988E9C);
  static const Color outlineVariantDark = Color(0xFF4A424E);

  // ---- Estados ----
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color success = Color(0xFF2E7D53);
  static const Color successContainer = Color(0xFFD9F2E3);
  static const Color warning = Color(0xFFB26A00);
  static const Color warningContainer = Color(0xFFFFEBCC);

  /// Tinte de las sombras: NO son grises, llevan el morado de marca al 10-15%.
  /// Es lo que da el efecto "luminoso" del sistema.
  static const Color shadowTint = Color(0xFF8204BE);
}
