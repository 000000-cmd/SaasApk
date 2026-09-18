import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/business/business_repository.dart';
import 'package:saas_app/core/business/team_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// "Dashboard de Negocio" del dueño en móvil: vista panorámica del imperio.
///
/// Solo muestra cifras REALES (saldo por liquidar, sedes, tamaño del equipo).
/// Ingresos y ocupación dependen del módulo de citas: sus recuadros existen con
/// el estado "próximamente" en vez de inventar datos.
class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key, this.onNavigate});

  /// Cambia de tab en el shell (1 = Liquidaciones, 2 = Equipo).
  final void Function(int tab)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final String name = (user?.fullName ?? user?.username ?? '').split(' ').first;
    final AsyncValue<MyBusiness?> business = ref.watch(myBusinessProvider);
    final List<TeamBalance> balances = ref.watch(teamBalancesProvider).valueOrNull ?? const [];
    final List<TeamMember> team = ref.watch(teamProvider).valueOrNull ?? const [];
    final List<Branch> branches = ref.watch(branchesProvider).valueOrNull ?? const [];

    final double pending = balances.fold(0, (a, b) => a + b.pending);
    final int payable = balances.where((b) => b.pending > 0).length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(teamBalancesProvider);
          ref.invalidate(branchesProvider);
          await ref.read(teamBalancesProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
          ),
          children: [
            Text(
              'PANEL DEL NEGOCIO',
              style: AppTypography.labelSm(color: scheme.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              name.isEmpty ? 'Bienvenido' : 'Bienvenido, $name',
              style: AppTypography.headlineLg(color: scheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              business.valueOrNull?.name ?? 'Vista panorámica de tu operación',
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Saldo a abonar: la decisión de plata del dueño ----
            _PendingCard(
              total: pending,
              employees: payable,
              onTap: () => onNavigate?.call(1),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Retícula: real + lo que llega con citas ----
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.storefront_outlined,
                    label: 'Sedes',
                    value: '${branches.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.groups_outlined,
                    label: 'Equipo',
                    value: '${team.length}',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: _MetricTile(
                    icon: Icons.event_available_outlined,
                    label: 'Citas hoy',
                    value: '—',
                    pending: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Sedes activas ----
            Text('Sedes activas', style: AppTypography.headlineMd(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.md),
            if (branches.isEmpty)
              const _Muted(text: 'Aún no has registrado sedes. Créalas desde la plataforma web.')
            else
              ...branches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _BranchRow(
                    name: b.name,
                    people: team.where((m) => m.branchId == b.id).length,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Insight del ORB ----
            _OrbInsight(pending: pending, payable: payable, team: team.length),
          ],
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.total, required this.employees, required this.onTap});
  final double total;
  final int employees;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            color: AppColors.ink900,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saldo a abonar',
                style: AppTypography.labelMd(color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatCOP(total), style: AppTypography.displayXl(color: Colors.white)),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      employees == 0
                          ? 'Tu equipo está al día'
                          : '$employees colaborador(es) por liquidar',
                      style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
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
              style: AppTypography.titleMd(color: pending ? scheme.outline : scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.name, required this.people});
  final String name;
  final int people;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.place_outlined,
              size: 18,
              color: AppColors.onPrimaryFixedVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleMd(color: scheme.onSurface),
            ),
          ),
          Text(
            people == 1 ? '1 persona' : '$people personas',
            style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Text(text, style: AppTypography.bodySm(color: scheme.onSurfaceVariant)),
    );
  }
}

/// El ORB como asistente contextual: lee el estado real y sugiere el siguiente paso.
class _OrbInsight extends StatelessWidget {
  const _OrbInsight({required this.pending, required this.payable, required this.team});
  final double pending;
  final int payable;
  final int team;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String message = payable > 0
        ? 'Tienes ${formatCOP(pending)} por liquidar a $payable colaborador(es).'
        : team == 0
            ? 'Da de alta a tu equipo desde la web para empezar a operar.'
            : 'Todo al día. Las cifras de ocupación llegarán con el módulo de citas.';

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
                  'Insight de Orbe',
                  style: AppTypography.titleMd(color: AppColors.onPrimaryFixedVariant),
                ),
                const SizedBox(height: 2),
                Text(message, style: AppTypography.bodySm(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
