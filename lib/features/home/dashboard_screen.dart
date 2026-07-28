
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/business/business_repository.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Inicio del empleado (pantalla "Dashboard del Empleado" del sistema).
///
/// El balance del periodo manda: vive en una tarjeta con el degradado de marca,
/// arriba del todo. Debajo, la retícula de resumen, la próxima cita y el
/// consejo del ORB.
///
/// Los recuadros que dependen del módulo de CITAS (citas del día, valoración,
/// próxima cita) se muestran con su estado "próximamente" en vez de omitirse:
/// la estructura es la del diseño, sin inventar cifras.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Cambia de tab en el shell (1 = Citas, 2 = Pagos).
  final void Function(int tab)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final String name = (user?.fullName ?? user?.username ?? '').split(' ').first;
    final AsyncValue<MyBusiness?> business = ref.watch(myBusinessProvider);
    final EmployeeBalance? balance = ref.watch(myBalanceProvider).valueOrNull;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
        ),
        children: [
          // ---- Saludo ----
          Text(
            _greeting(name),
            style: AppTypography.headlineLg(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Esto es lo tuyo, al día.',
            style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ---- Balance del periodo (read model desde Elasticsearch) ----
          _BalanceHero(
            balance: balance?.balance ?? 0,
            onSeePayments: () => onNavigate?.call(2),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Retícula de resumen ----
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.payments_outlined,
                  label: 'Devengado',
                  value: formatCOP(balance?.accrued ?? 0),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: _StatTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Citas hoy',
                  value: '—',
                  pending: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: _StatTile(
                  icon: Icons.star_outline_rounded,
                  label: 'Valoración',
                  value: '—',
                  pending: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ---- Próxima cita (a la espera del módulo de citas) ----
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Próxima cita',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMd(color: scheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => onNavigate?.call(1),
                child: const Text('Ver agenda'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const _UpcomingAppointmentPlaceholder(),
          const SizedBox(height: AppSpacing.xl),

          // ---- Consejo del ORB ----
          _OrbTip(name: name, hasBalance: (balance?.balance ?? 0) > 0),

          // ---- Contexto del negocio (solo datos reales) ----
          business.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (b) => b == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                        boxShadow: AppElevation.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: AppColors.onPrimaryFixedVariant,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.name, style: AppTypography.titleMd(color: scheme.onSurface)),
                                if (b.tradeName != null && b.tradeName!.isNotEmpty)
                                  Text(
                                    b.tradeName!,
                                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Saludo por franja horaria (el diseño abre con "Good Morning, …").
  String _greeting(String name) {
    final int h = DateTime.now().hour;
    final String part = h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
    return name.isEmpty ? part : '$part, $name';
  }
}

/// Hero del saldo: degradado de marca, cifra gigante y acceso al historial.
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.onSeePayments, this.balance = 0});
  final VoidCallback onSeePayments;
  final num balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        boxShadow: AppElevation.glow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          children: [
            // Destellos difusos: profundidad sin competir con la cifra.
            Positioned(
              right: -48,
              top: -48,
              child: _Blob(size: 190, color: Colors.white.withValues(alpha: 0.10)),
            ),
            Positioned(
              left: -32,
              bottom: -32,
              child: _Blob(size: 130, color: AppColors.primaryFixed.withValues(alpha: 0.20)),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          // No es "saldo por cobrar": nadie le debe esto
                          // todavía. Es lo acumulado que se cobrará en la
                          // próxima liquidación, y llamarlo por su nombre
                          // evita que se lea como una deuda vencida.
                          'Tu balance del mes',
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm - 2),
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatCOP(balance),
                      style: AppTypography.displayXl(color: Colors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Se acumula con cada servicio y se te paga en la próxima liquidación.',
                    style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MiniBadge(icon: Icons.account_balance_wallet_outlined),
                          SizedBox(width: AppSpacing.sm - 4),
                          _MiniBadge(icon: Icons.trending_up_rounded),
                        ],
                      ),
                      // Botón de cristal sobre el degradado.
                      Material(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          onTap: onSeePayments,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2,
                            ),
                            child: Text(
                              'Ver detalles',
                              style: AppTypography.labelMd(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: 15, color: Colors.white),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Recuadro de la retícula de resumen. `pending` marca lo que llega con citas.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.pending = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: pending ? scheme.outline : scheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.titleMd(
                color: pending ? scheme.outline : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Próxima cita: la estructura del diseño con su estado a la espera de citas.
class _UpcomingAppointmentPlaceholder extends StatelessWidget {
  const _UpcomingAppointmentPlaceholder();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border(left: BorderSide(color: scheme.outlineVariant, width: 4)),
        boxShadow: AppElevation.card,
      ),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(Icons.event_outlined, color: scheme.outline),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sin citas todavía', style: AppTypography.titleMd(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(
                  'Tu agenda aparecerá aquí cuando entre el módulo de citas.',
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

/// Burbuja del ORB: consejo contextual, la presencia "viva" del sistema.
class _OrbTip extends StatelessWidget {
  const _OrbTip({required this.name, required this.hasBalance});
  final String name;
  final bool hasBalance;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String tip = hasBalance
        ? 'Este es tu acumulado del periodo. Se te paga cuando tu dueño liquide.'
        : 'Tu balance arranca en cero y sube solo con cada servicio que completes.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 56, width: 56, child: OrbMascot(size: 56, halo: true)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip de Orbe',
                  style: AppTypography.titleMd(color: AppColors.onPrimaryFixedVariant),
                ),
                const SizedBox(height: 2),
                Text(tip, style: AppTypography.bodySm(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
