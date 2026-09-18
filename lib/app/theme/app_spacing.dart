import 'package:flutter/widgets.dart';

/// Tokens de espaciado y radios. Usar en vez de números mágicos.
///
/// El sistema **Vertex** es de formas "Structured Modern": base de 8px, que deja
/// los elementos aproximables pero conserva la línea precisa de una herramienta
/// profesional. El círculo se reserva para avatares e indicadores de estado —
/// botones y campos NUNCA son píldoras.
class AppSpacing {
  AppSpacing._();

  /// Aire al final de una lista. La barra inferior va ANCLADA al borde, así que
  /// el Scaffold ya le reserva su alto y el de la barra de gestos: aquí sólo
  /// queda el respiro visual para que el último elemento no toque el borde.
  static double bottomForNavBar(BuildContext context) => xxl;

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
  static const double radiusSm = 4;
  /// Base del sistema: botones, campos y chips.
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  /// Tarjetas: 12px — esquina suave sin perder la silueta arquitectónica.
  static const double radiusCard = 12;
  /// Contenedores grandes.
  static const double radiusXl = 16;
  /// Hojas inferiores: el único sitio donde el radio se abre de verdad.
  static const double radiusXxl = 20;
  static const double radiusFull = 999;
}
