import 'package:flutter/material.dart';

/// Paleta del design system **Vertex** de Moda ERP (la misma que la web).
///
/// Dos ejes de color, igual que en `styles.scss`:
///  - **Tinta estructural** (Midnight Navy, matiz 266): superficies, bordes,
///    texto y los bloques "autoritativos". Es el ancla neutral del sistema.
///  - **Acento** (Electric Cerulean, matiz 238): lo interactivo — botones,
///    enlaces, pestaña activa, progreso.
///
/// Los verdes/ámbar/rojos NO siguen al acento a propósito: verde-es-bueno y
/// rojo-es-malo son convenciones, no marca.
///
/// Los valores salen de la misma rampa OKLCH que la web (ver
/// `scratchpad/tokens.mjs`), convertidos a sRGB. Las pantallas NO deben
/// hardcodear colores: todo sale de aquí o del [ThemeData].
class AppColors {
  AppColors._();

  // ---- Acento del tenant (cerúleo por defecto) ----
  static const Color primary = Color(0xFF0084D2);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFF006BB2);
  static const Color primaryLight = Color(0xFF28A3E4);
  static const Color primaryContainer = Color(0xFF131B2E);
  static const Color onPrimaryContainer = Color(0xFF9BA5B9);
  static const Color primaryFixed = Color(0xFFC5E9FF);
  static const Color primaryFixedDim = Color(0xFF96CFF6);
  static const Color onPrimaryFixed = Color(0xFF001D33);
  static const Color onPrimaryFixedVariant = Color(0xFF004B6F);
  static const Color inversePrimary = Color(0xFF68BBEF);
  static const Color surfaceTint = Color(0xFF0084D2);

  // ---- Tinta estructural (Midnight Navy) ----
  // Constante entre claro y oscuro: es estructura, no superficie.
  static const Color ink50 = Color(0xFFEEF2FA);
  static const Color ink100 = Color(0xFFDDE3F1);
  static const Color ink200 = Color(0xFFBFC7DA);
  static const Color ink300 = Color(0xFF9BA5B9);
  static const Color ink400 = Color(0xFF79839A);
  static const Color ink500 = Color(0xFF545D73);
  static const Color ink600 = Color(0xFF3B455B);
  static const Color ink700 = Color(0xFF263046);
  static const Color ink800 = Color(0xFF1B2338);
  static const Color ink900 = Color(0xFF131B2E);
  static const Color ink950 = Color(0xFF060B18);

  // ---- Secundario / terciario ----
  // `secondaryContainer` es el cerúleo eléctrico del sistema de diseño: se usa
  // en rellenos brillantes sobre tinta (CTA del panel oscuro, barras de avance).
  static const Color secondary = Color(0xFF006BB2);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF3AB8FD);
  static const Color onSecondaryContainer = Color(0xFF024565);
  static const Color secondaryFixed = Color(0xFFC6E7FD);
  static const Color secondaryFixedDim = Color(0xFF85CEFC);
  static const Color onSecondaryFixed = Color(0xFF001D2E);
  static const Color onSecondaryFixedVariant = Color(0xFF014A6D);
  static const Color tertiary = Color(0xFF009465);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF002113);
  static const Color onTertiaryContainer = Color(0xFF089667);
  static const Color tertiaryFixed = Color(0xFF85F7C2);
  static const Color tertiaryFixedDim = Color(0xFF4FDEA3);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF015337);

  // ---- Superficies (claro) ----
  static const Color background = Color(0xFFF8FAFD);
  static const Color onBackground = Color(0xFF111A30);
  static const Color surface = Color(0xFFF8FAFD);
  static const Color surfaceBright = Color(0xFFF8FAFD);
  static const Color surfaceDim = Color(0xFFCEDAF5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F4FD);
  static const Color surfaceContainer = Color(0xFFE7EEFB);
  static const Color surfaceContainerHigh = Color(0xFFE0E8FA);
  static const Color surfaceContainerHighest = Color(0xFFD9E3F9);
  static const Color surfaceVariant = Color(0xFFD9E3F9);
  static const Color onSurface = Color(0xFF111A30);
  static const Color onSurfaceVariant = Color(0xFF434853);
  static const Color inverseSurface = Color(0xFF263046);
  static const Color inverseOnSurface = Color(0xFFEBF2FF);
  static const Color outline = Color(0xFF737781);
  static const Color outlineVariant = Color(0xFFCFD4E1);

  // ---- Superficies (oscuro) ----
  // No es un gris neutro: es el mismo Midnight Navy, así el modo oscuro se lee
  // como la misma marca y no como otra app.
  static const Color backgroundDark = Color(0xFF090D17);
  static const Color surfaceDarkTone = Color(0xFF090D17);
  static const Color surfaceContainerLowestDark = Color(0xFF03060D);
  static const Color surfaceContainerLowDark = Color(0xFF121723);
  static const Color surfaceContainerDark = Color(0xFF181E2B);
  static const Color surfaceContainerHighDark = Color(0xFF222938);
  static const Color surfaceContainerHighestDark = Color(0xFF2E3546);
  static const Color onSurfaceDark = Color(0xFFEEF2FA);
  static const Color onSurfaceVariantDark = Color(0xFFAAB1C0);
  static const Color outlineDark = Color(0xFF858C9D);
  static const Color outlineVariantDark = Color(0xFF2D3547);

  // ---- Estados ----
  static const Color error = Color(0xFFBA181C);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD5);
  static const Color onErrorContainer = Color(0xFF93000C);
  static const Color success = Color(0xFF00774E);
  static const Color successContainer = Color(0xFFCBF3DE);
  static const Color warning = Color(0xFFA96B00);
  static const Color warningContainer = Color(0xFFFFE3BC);

  /// Tinte de las sombras: la tinta estructural, no un gris neutro. El sistema
  /// evita sombras densas — la profundidad viene de las capas tonales y del
  /// borde de 1px, así que esto sólo despega el objeto lo justo.
  static const Color shadowTint = Color(0xFF131B2E);
}
