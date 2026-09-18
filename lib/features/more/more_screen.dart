import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/finance/bank_account_repository.dart';
import 'package:saas_app/core/notifications/inbox_repository.dart';
import 'package:saas_app/features/more/bank_accounts_screen.dart';
import 'package:saas_app/features/profile/profile_screen.dart';

/// Todo lo que el empleado gestiona de sí mismo, en un sitio.
///
/// Es el carril de "lo que no se hace todos los días": sus datos, sus cuentas,
/// su seguridad. Sacarlo de las otras tres pestañas es lo que las deja
/// dedicadas a lo diario — el trabajo y la plata.
///
/// Cada casilla LLEVA A ALGO. La regla es esa: si algo aquí no abre nada, no
/// tiene por qué estar.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final int unread = ref.watch(unreadCountProvider).value ?? 0;
    final int cuentas = ref.watch(myBankAccountsProvider).valueOrNull?.length ?? 0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile,
          AppSpacing.bottomForNavBar(context),
        ),
        children: [
          Text('Más', style: AppTypography.headlineLg(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.xl),

          // Identidad arriba: es lo que responde "¿esta app es mía?".
          _Fila(
            icon: Icons.person_outline_rounded,
            titulo: user?.fullName ?? user?.username ?? 'Mi perfil',
            detalle: 'Tus datos, tu foto y tu contraseña',
            destacada: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Mi perfil')),
                  body: const ProfileScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Fila(
            icon: Icons.account_balance_outlined,
            titulo: 'Mis cuentas',
            // El contador dice si hay algo que arreglar. Sin cuenta no le
            // pueden pagar, y eso es lo único que hay que sacar a relucir aquí.
            detalle: cuentas == 0
                ? 'Sin cuentas — no podrán pagarte'
                : (cuentas == 1 ? '1 cuenta registrada' : '$cuentas cuentas registradas'),
            alerta: cuentas == 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BankAccountsScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _Fila(
            icon: Icons.notifications_none_rounded,
            titulo: 'Notificaciones',
            detalle: unread > 0 ? '$unread sin leer' : 'Todo al día',
            onTap: () async {
              await context.push('/notifications');
              ref.invalidate(unreadCountProvider);
            },
          ),

          const SizedBox(height: AppSpacing.section),
          Center(
            child: Text(
              'Tu jefe aprueba los servicios y hace los pagos.\n'
              'Aquí solo mandas tú sobre lo tuyo.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icon,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.destacada = false,
    this.alerta = false,
  });

  final IconData icon;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;
  final bool destacada;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          boxShadow: AppElevation.card,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: destacada ? AppColors.primaryFixed : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: destacada ? AppColors.onPrimaryFixedVariant : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm(
                          color: alerta ? scheme.error : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
