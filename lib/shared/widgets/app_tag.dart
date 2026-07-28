import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

enum AppTagTone { primary, success, warning, neutral, danger }

/// Etiqueta tipo píldora para estados ("Confirmado", "En servicio").
///
/// Fondo de baja saturación + texto del mismo tono en oscuro: el sistema pide
/// que los estados se lean sin gritar. Opcionalmente con punto indicador.
class AppTag extends StatelessWidget {
  const AppTag({super.key, required this.label, this.tone = AppTagTone.neutral, this.dot = false});

  final String label;
  final AppTagTone tone;

  /// Punto de color a la izquierda (estados "en vivo").
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      AppTagTone.primary => (AppColors.primaryFixed, AppColors.onPrimaryFixedVariant),
      AppTagTone.success => (AppColors.successContainer, AppColors.success),
      AppTagTone.warning => (AppColors.warningContainer, AppColors.warning),
      AppTagTone.danger => (AppColors.errorContainer, AppColors.onErrorContainer),
      AppTagTone.neutral => (AppColors.secondaryContainer, AppColors.onSecondaryContainer),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dot ? AppSpacing.md : AppSpacing.md,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
          ],
          Text(label.toUpperCase(), style: AppTypography.labelSm(color: fg)),
        ],
      ),
    );
  }
}
