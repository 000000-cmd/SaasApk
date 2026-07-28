import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Botón del sistema "Luminous Aura". Usar en vez de [ElevatedButton] crudos.
///
/// La acción primaria es una PÍLDORA con degradado sutil morado→violeta y halo
/// luminoso: contrasta a propósito contra la retícula ortogonal del resto de la
/// interfaz. La secundaria es transparente con trazo morado.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.loading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool disabled = onPressed == null || loading;
    final double height = switch (size) {
      AppButtonSize.sm => 40,
      AppButtonSize.lg => 56,
      AppButtonSize.md => 48,
    };
    final double fontSize = size == AppButtonSize.sm ? 13 : 15;
    final _BtnColors colors = _colorsFor(scheme);

    final Widget child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(colors.fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 4, color: colors.fg),
                const SizedBox(width: AppSpacing.sm),
              ],
              // Flexible + elipsis: una etiqueta larga se recorta en vez de
              // desbordar la fila (pasaba en pantallas de 375px).
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMd(color: colors.fg).copyWith(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );

    final Widget button = Opacity(
      opacity: disabled ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          gradient: colors.gradient,
          color: colors.gradient == null ? colors.bg : null,
          border: colors.border == null ? null : Border.all(color: colors.border!, width: 1.5),
          // El halo solo lo lleva la acción primaria: es la que debe atraer.
          boxShadow: !disabled && variant == AppButtonVariant.primary ? AppElevation.glow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            onTap: disabled ? null : onPressed,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  _BtnColors _colorsFor(ColorScheme scheme) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _BtnColors(
          bg: scheme.primary,
          fg: scheme.onPrimary,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryContainer, AppColors.primary],
          ),
        );
      case AppButtonVariant.secondary:
        return _BtnColors(
          bg: Colors.transparent,
          fg: scheme.primary,
          border: scheme.primary.withValues(alpha: 0.4),
        );
      case AppButtonVariant.ghost:
        return _BtnColors(bg: Colors.transparent, fg: scheme.onSurfaceVariant);
      case AppButtonVariant.danger:
        return _BtnColors(bg: scheme.error, fg: scheme.onError);
    }
  }
}

class _BtnColors {
  const _BtnColors({required this.bg, required this.fg, this.border, this.gradient});
  final Color bg;
  final Color fg;
  final Color? border;
  final Gradient? gradient;
}
