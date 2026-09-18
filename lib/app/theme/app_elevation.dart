import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';

/// Profundidad del sistema **Vertex**.
///
/// El sistema evita sombras densas y turbias: la profundidad viene de las
/// **capas tonales** y del **borde nítido de 1px**. Estas sombras sólo despegan
/// el objeto lo justo, con el tinte de la tinta estructural (no gris neutro).
class AppElevation {
  AppElevation._();

  /// Tarjetas en reposo. Casi imperceptible: manda el borde.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Tarjetas destacadas / al pulsar.
  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -6,
        ),
      ];

  /// Hojas y diálogos: lo único que flota de verdad sobre la página.
  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.07),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.18),
          blurRadius: 40,
          offset: const Offset(0, 16),
          spreadRadius: -12,
        ),
      ];

  /// Barra inferior (va hacia arriba).
  static List<BoxShadow> get bar => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, -6),
          spreadRadius: -6,
        ),
      ];
}
