import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

class AppNavItem {
  const AppNavItem({
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

/// Barra inferior del sistema **Vertex**.
///
/// Va anclada al borde, con un borde superior de 1px y superficie sólida: es
/// estructura de la app, no un objeto que flota encima. Nada de blur ni halos —
/// la profundidad del sistema viene de las capas tonales.
///
/// El estado activo se lee de dos formas a la vez, porque en un teléfono no hay
/// cursor que ayude: la píldora de acento **se desliza** de un sitio a otro (el
/// ojo sigue a dónde fue) y sólo el activo muestra su etiqueta. Al presionar, el
/// objetivo se hunde y vibra: la respuesta llega por el dedo, no por la vista.
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.items, required this.index, required this.onTap});

  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  static const Duration slide = Duration(milliseconds: 320);
  static const Curve curve = Curves.easeOutCubic;
  static const double barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Margen real bajo la barra de gestos del sistema.
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double slot = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: slide,
                  curve: curve,
                  left: slot * index + AppSpacing.sm,
                  top: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  width: slot - AppSpacing.lg,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
    );
  }
}

/// Un objetivo de la barra. Se hunde al presionar y saca su etiqueta al quedar
/// activo.
class _NavTarget extends StatefulWidget {
  const _NavTarget({required this.item, required this.active, required this.onTap});

  final AppNavItem item;
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
    final Color tint = widget.active ? scheme.primary : scheme.onSurfaceVariant;

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
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    widget.active ? widget.item.activeIcon : widget.item.icon,
                    size: 22,
                    color: tint,
                  ),
                  if (widget.item.locked)
                    Positioned(
                      right: -7,
                      top: -3,
                      child: Icon(Icons.lock, size: 11, color: scheme.outline),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // La etiqueta existe siempre (el test la busca y el lector de
              // pantalla la anuncia); sólo se atenúa cuando no está activa.
              AnimatedDefaultTextStyle(
                duration: AppNavBar.slide,
                curve: AppNavBar.curve,
                style: AppTypography.labelSm(color: tint).copyWith(
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
