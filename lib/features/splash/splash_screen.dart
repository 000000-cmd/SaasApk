import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Pantalla puente mientras se restaura la sesión (ver AuthController._restore).
/// La mascota en modo `loading` ES el loader: no hace falta spinner encima.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OrbMascot(size: 200, halo: true, loading: true),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'Preparando tu espacio…',
              style: AppTypography.labelMd(color: AppColors.secondaryFixedDim),
            ),
          ],
        ),
      ),
    );
  }
}
