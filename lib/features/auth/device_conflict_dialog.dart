import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/device_conflict.dart';

/// "Tu cuenta ya está abierta en otro dispositivo. ¿La cerramos?"
///
/// Se enseña cuando la contraseña era correcta pero hay una sesión viva en otro
/// sitio. Es una decisión, no un error, y por eso muestra QUÉ se va a cerrar
/// —el nombre del teléfono y cuándo se usó por última vez— antes de pedir la
/// confirmación. Sin ese detalle, la persona no puede distinguir su móvil viejo
/// de un acceso que no reconoce, que es justo lo que importa saber.
///
/// Devuelve `true` si acepta desvincular.
Future<bool> showDeviceConflictDialog(BuildContext context, DeviceConflict conflict) async {
  final ColorScheme scheme = Theme.of(context).colorScheme;

  final bool? ok = await showDialog<bool>(
    context: context,
    // No se cierra tocando fuera: es una decisión de seguridad, y salirse por
    // accidente dejaría la pantalla en un estado que no se explica solo.
    barrierDismissible: false,
    builder: (BuildContext ctx) => AlertDialog(
      icon: Icon(Icons.devices_other_outlined, color: scheme.primary, size: 28),
      title: Text(
        conflict.hasOtherAccount && !conflict.hasOtherDevice
            ? 'Este teléfono tiene otra sesión'
            : 'Tu cuenta está abierta en otro dispositivo',
        style: AppTypography.headlineMd(color: scheme.onSurface),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ConflictItem i in conflict.items) ...<Widget>[
            _Fila(item: i, scheme: scheme),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            conflict.consequence,
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Entrar aquí'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

class _Fila extends StatelessWidget {
  const _Fila({required this.item, required this.scheme});

  final ConflictItem item;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final bool esOtraCuenta = item.kind == ConflictItem.otherAccount;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            esOtraCuenta ? Icons.person_outline : Icons.smartphone_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  esOtraCuenta ? item.account : item.deviceName,
                  style: AppTypography.labelMd(color: scheme.onSurface),
                ),
                if (item.relative.isNotEmpty)
                  Text(
                    esOtraCuenta
                        ? 'Última vez en este teléfono: ${item.relative}'
                        : 'Última vez: ${item.relative}',
                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
