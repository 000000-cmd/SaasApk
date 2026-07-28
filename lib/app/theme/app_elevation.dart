import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';

/// Profundidad del sistema "Luminous Aura".
///
/// La sombra NO es gris: lleva un tinte del morado de marca, lo que produce el
/// halo atmosférico característico. Las tarjetas se definen por su sombra, no
/// por bordes duros.
class AppElevation {
  AppElevation._();

  /// Tarjetas en reposo.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.08),
          blurRadius: 30,
          offset: const Offset(0, 10),
          spreadRadius: -5,
        ),
      ];

  /// Tarjetas destacadas / al pulsar.
  static List<BoxShadow> get raised => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.15),
          blurRadius: 40,
          offset: const Offset(0, 20),
          spreadRadius: -10,
        ),
      ];

  /// Acciones primarias y el orb: el halo se nota.
  static List<BoxShadow> get glow => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.30),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ];

  /// Barra inferior (va hacia arriba).
  static List<BoxShadow> get bar => [
        BoxShadow(
          color: AppColors.shadowTint.withValues(alpha: 0.10),
          blurRadius: 30,
          offset: const Offset(0, -8),
        ),
      ];
}
