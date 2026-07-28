import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

class OrbNavItem {
  const OrbNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.locked = false,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Función aún no disponible: se muestra con un candadito (p. ej. Citas).
  final bool locked;
}

/// Barra inferior del sistema "Luminous Aura", en el lenguaje del dock de la
/// web pero pensada para el dedo.
///
/// El dock de escritorio magnifica lo que está bajo el cursor. **En un teléfono
/// no hay cursor**: copiar el hover daría una barra que no reacciona nunca. El
/// mismo gesto se traduce a lo que sí existe en táctil:
///
///  - la píldora del activo se DESLIZA de un sitio a otro en vez de aparecer y
///    desaparecer, así el ojo sigue a dónde fue;
///  - el icono activo crece y saca su etiqueta; los demás se quedan en icono,
///    que es lo que deja sitio para que el activo respire;
///  - al presionar, el objetivo se hunde y vibra: la respuesta llega por el
///    dedo, no por la vista, que es como se navega con el pulgar.
///
/// Va flotando y separada de los bordes para quedar POR ENCIMA de la barra de
/// gestos del teléfono, nunca debajo.
class OrbNavBar extends StatelessWidget {
  const OrbNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<OrbNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  static const Duration slide = Duration(milliseconds: 380);
  static const Curve curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // Margen real bajo la barra de gestos del sistema.
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        bottomInset > 0 ? bottomInset * 0.5 + AppSpacing.sm : AppSpacing.lg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withValues(alpha: dark ? 0.82 : 0.92),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: dark ? 0.22 : 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double slot = constraints.maxWidth / items.length;
                return Stack(
                  children: [
                    // La píldora viaja: es lo que hace legible el cambio de
                    // pestaña sin tener que leer los iconos.
                    AnimatedPositioned(
                      duration: slide,
                      curve: curve,
                      left: slot * index + AppSpacing.xs,
                      top: AppSpacing.xs + 2,
                      bottom: AppSpacing.xs + 2,
                      width: slot - AppSpacing.sm,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: dark ? 0.30 : 0.16),
                              AppColors.primary.withValues(alpha: dark ? 0.16 : 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
                        ),
                      ),
                    ),
                    Row(
                      children: List<Widget>.generate(items.length, (i) {
                        return Expanded(
                          child: _NavTarget(
                            item: items[i],
                            active: i == index,
                            onTap: () {
                              if (i != index) HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Un objetivo de la barra. Se hunde al presionar (la respuesta que en
/// escritorio daba el hover) y crece cuando queda activo.
class _NavTarget extends StatefulWidget {
  const _NavTarget({required this.item, required this.active, required this.onTap});

  final OrbNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavTarget> createState() => _NavTargetState();
}

class _NavTargetState extends State<_NavTarget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tint = widget.active ? AppColors.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: widget.active,
      button: true,
      label: widget.item.locked ? '${widget.item.label} (próximamente)' : widget.item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // El icono activo crece: la magnificación del dock, pero
                  // atada a la selección en vez de al cursor.
                  AnimatedScale(
                    scale: widget.active ? 1.12 : 1,
                    duration: OrbNavBar.slide,
                    curve: OrbNavBar.curve,
                    child: Icon(
                      widget.active ? widget.item.activeIcon : widget.item.icon,
                      size: 23,
                      color: tint,
                    ),
                  ),
                  if (widget.item.locked)
                    Positioned(
                      right: -7,
                      top: -3,
                      child: Icon(Icons.lock, size: 11, color: scheme.outline),
                    ),
                ],
              ),
              // La etiqueta va SIEMPRE, no solo en la activa. Los nombres los
              // pone la configuración y sus iconos se mapean a Material: los
              // que no tienen equivalente caen en un círculo genérico, así que
              // sin texto podrían verse tres pestañas idénticas. Lo que
              // distingue a la activa es el peso y el color, no la ausencia de
              // etiqueta en las demás.
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: AnimatedDefaultTextStyle(
                  duration: OrbNavBar.slide,
                  curve: OrbNavBar.curve,
                  style: AppTypography.labelMd(color: tint).copyWith(
                    fontSize: widget.active ? 11 : 10.5,
                    fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
