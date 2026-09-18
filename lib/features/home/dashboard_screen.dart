import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/service_charge_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/core/notifications/inbox_repository.dart';
import 'package:saas_app/features/payments/cash_confirmation_card.dart';
import 'package:saas_app/features/services/services_screen.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';

/// Inicio del empleado. TRES cosas, en este orden:
///
///   1. lo que hay que hacer hoy —si hay algo—, porque es lo único urgente;
///   2. su saldo, que es la razón de abrir la app;
///   3. su agenda de hoy, tocable una por una.
///
/// Nada más. Antes había una retícula con "Citas hoy: —" y "Valoración: —" que
/// no llevaban a ningún sitio, un consejo de la mascota y la ficha del negocio:
/// tres bloques que ocupaban media pantalla para no responder ninguna pregunta.
/// Lo que no se puede tocar ni cambia nada, aquí no va.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Cambia de pestaña en el shell (1 = Servicios, 2 = Movimientos).
  final void Function(int tab)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final String name = (user?.fullName ?? user?.username ?? '').split(' ').first;

    final AsyncValue<EmployeeBalance> balance = ref.watch(myBalanceProvider);
    final AsyncValue<List<ServiceItem>> servicios = ref.watch(myServicesProvider);
    final List<ServiceItem> hoy = ref.watch(todayServicesProvider);
    final List<SettlementEntry> efectivo =
        (ref.watch(mySettlementsProvider).valueOrNull ?? const [])
            .where((e) => e.cashPendingConfirmation)
            .toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myBalanceProvider);
          await Future.wait([
            ref.read(myServicesProvider.future),
            ref.read(mySettlementsProvider.future),
          ]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile,
            AppSpacing.bottomForNavBar(context),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _saludo(name),
                    style: AppTypography.headlineLg(color: scheme.onSurface),
                  ),
                ),
                const _Campana(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Lo que le piden a él ----
            // Va PRIMERO y solo si existe: es lo único de la app que espera algo
            // suyo, y debajo del saldo nadie lo vería.
            CashConfirmationCard(entries: efectivo),

            // ---- Su saldo ----
            _SaldoCard(
              saldo: balance.valueOrNull?.balance ?? 0,
              cargando: balance.isLoading,
              onTap: () => onNavigate?.call(2),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Hoy ----
            Row(
              children: [
                Expanded(
                  child: Text('Hoy', style: AppTypography.headlineMd(color: scheme.onSurface)),
                ),
                if (hoy.isNotEmpty)
                  TextButton(
                    onPressed: () => onNavigate?.call(1),
                    child: const Text('Ver todos'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            if (servicios.isLoading)
              const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: AppLoader())
            else if (hoy.isEmpty)
              _SinCitas(onVerAgenda: () => onNavigate?.call(1))
            else
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                  boxShadow: AppElevation.card,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < hoy.length; i++) ...[
                      // La MISMA fila que en Servicios: tocarla abre el detalle
                      // y desde ahí se marca terminado. Un maquetado propio para
                      // esto sería una segunda copia que se desincroniza sola.
                      ServiceRow(item: hoy[i]),
                      if (i < hoy.length - 1)
                        Divider(
                          height: 1,
                          indent: AppSpacing.section + AppSpacing.md,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _saludo(String name) {
    final int h = DateTime.now().hour;
    final String parte = h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
    return name.isEmpty ? parte : '$parte, $name';
  }
}

/// El saldo. Una sola cifra, un solo destino al tocarla.
///
/// Ya no lleva insignias decorativas ni un botón "Ver detalles" aparte: la
/// tarjeta ENTERA es el botón, que es lo que el dedo intenta primero.
class _SaldoCard extends StatelessWidget {
  const _SaldoCard({required this.saldo, required this.cargando, required this.onTap});
  final double saldo;
  final bool cargando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        onTap: onTap,
        // Panel en tinta estructural: el mismo navy del sistema. Sólido, sin
        // degradado ni halo — lo que debe destacar es la CIFRA, no la caja.
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            color: AppColors.ink900,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TU SALDO',
                  style: AppTypography.labelSm(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (cargando)
                  const SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCOP(saldo),
                      style: AppTypography.displayXl(color: Colors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ya es tuyo. Se te consigna en la próxima nómina.',
                        style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.9)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Día sin citas. Dice qué pasa y deja un camino, en vez de una ilustración.
class _SinCitas extends StatelessWidget {
  const _SinCitas({required this.onVerAgenda});
  final VoidCallback onVerAgenda;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        children: [
          Icon(Icons.free_breakfast_outlined, size: 26, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text('Hoy no tienes citas', style: AppTypography.titleMd(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mira tu agenda para ver qué viene.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onVerAgenda, child: const Text('Ver mi agenda')),
        ],
      ),
    );
  }
}

/// Campana: abre la bandeja y dice cuántas hay sin leer.
class _Campana extends ConsumerWidget {
  const _Campana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int unread = ref.watch(unreadCountProvider).value ?? 0;

    return IconButton(
      tooltip: 'Notificaciones',
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(unreadCountProvider);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.primary,
        label: Text(unread > 9 ? '9+' : '$unread'),
        child: Icon(Icons.notifications_none_rounded, color: scheme.onSurface),
      ),
    );
  }
}
