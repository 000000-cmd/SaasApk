import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

/// Tarjeta del sistema **Vertex**.
///
/// Nivel 1 de elevación: superficie sólida + borde de 1px y CERO sombra en
/// reposo. La profundidad viene de las capas tonales, no del difuminado; sólo
/// la tarjeta `raised` (destacada o pulsada) se despega.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.padding,
    this.onTap,
    this.raised = false,
    this.radius = AppSpacing.radiusCard,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Tarjeta destacada: sombra más profunda.
  final bool raised;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppTypography.titleMd(color: scheme.onSurface)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(subtitle!, style: AppTypography.bodySm(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          child,
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: raised ? AppElevation.raised : null,
      ),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}
