import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Agenda de citas — módulo bloqueado "próximamente". La pantalla ya planta la
/// base (tab propio, layout, copy) para conectar el módulo real sin rediseñar.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agenda', style: AppTypography.headlineLg(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tu agenda del día, en un vistazo.',
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mascota dormida + candado: bloqueado, no ausente.
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const OrbMascot(size: 180, dim: true),
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: AppColors.inverseSurface.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.outlineDark),
                          ),
                          child: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primaryFixedDim),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        'PRÓXIMAMENTE',
                        style: AppTypography.labelSm(color: AppColors.onPrimaryFixedVariant),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Aquí verás tus citas del día, quién viene y a qué hora. '
                        'Se activará junto con el módulo de agenda.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
