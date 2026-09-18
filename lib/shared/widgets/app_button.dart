import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

/// `ink` es el botón "autoritativo": tinta estructural sobre superficie clara,
/// el máximo contraste posible. Se reserva para la acción que cierra un flujo
/// (confirmar, aprobar). `primary` lleva el acento y es la acción habitual.
enum AppButtonVariant { primary, ink, secondary, ghost, danger }

enum AppButtonSize { sm, md, lg }

/// Botón del sistema **Vertex**. Usar en vez de [ElevatedButton] crudos.
///
/// Silueta de 8px en todas las variantes: nada de píldoras — el círculo se
/// reserva para avatares e indicadores. El primario es relleno sólido del
/// acento (sin degradado ni halo); el secundario, un borde de 1px.
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

    final BorderRadius shape = BorderRadius.circular(AppSpacing.radiusMd);
    final Widget button = Opacity(
      opacity: disabled ? 0.45 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape,
          color: colors.bg,
          border: colors.border == null ? null : Border.all(color: colors.border!),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: shape,
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
        return _BtnColors(bg: scheme.primary, fg: scheme.onPrimary);
      case AppButtonVariant.ink:
        return const _BtnColors(bg: AppColors.ink900, fg: AppColors.ink50);
      case AppButtonVariant.secondary:
        return _BtnColors(
          bg: Colors.transparent,
          fg: scheme.onSurface,
          border: scheme.outlineVariant,
        );
      case AppButtonVariant.ghost:
        return _BtnColors(bg: Colors.transparent, fg: scheme.onSurfaceVariant);
      case AppButtonVariant.danger:
        return _BtnColors(bg: scheme.error, fg: scheme.onError);
    }
  }
}

class _BtnColors {
  const _BtnColors({required this.bg, required this.fg, this.border});
  final Color bg;
  final Color fg;
  final Color? border;
}
