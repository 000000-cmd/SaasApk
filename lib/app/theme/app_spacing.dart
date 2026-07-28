import 'package:flutter/widgets.dart';

/// Tokens de espaciado y radios. Usar en vez de números mágicos.
///
/// El sistema "Luminous Aura" es de formas ORGÁNICAS: las tarjetas usan 24px
/// como mínimo (imitan la curvatura del orb) y las acciones primarias son
/// píldoras completas. Los radios chicos quedan solo para inputs y chips.
class AppSpacing {
  AppSpacing._();

  /// Aire que hay que dejar al final de una lista para que su último elemento
  /// no quede debajo de la barra inferior flotante ni de la barra de gestos
  /// del teléfono. La barra mide 68 y va separada del borde.
  static double bottomForNavBar(BuildContext context) =>
      68 + xxl + MediaQuery.viewPaddingOf(context).bottom;

  // Ritmo base de 8px; los cortes de sección respiran mucho más (32-64px).
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double section = 48;

  /// Margen lateral en móvil (equivale a `margin-mobile` del sistema).
  static const double marginMobile = 24;

  // ---- Radios ----
  static const double radiusSm = 8;
  /// Inputs: 12px, equilibrio entre el dato duro y la fluidez de la marca.
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  /// Tarjetas: mínimo 24px por mandato del sistema de diseño.
  static const double radiusCard = 24;
  /// Contenedores grandes / hojas: 28-32px.
  static const double radiusXl = 28;
  static const double radiusXxl = 32;
  static const double radiusFull = 999;
}
