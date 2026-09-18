import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/business/team_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_button.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';

/// "Liquidaciones Pendientes" del dueño.
///
/// Los saldos vienen del read model de Elasticsearch; confirmar va contra
/// finance-service, que mueve el dinero. Es IRREVERSIBLE, así que siempre pide
/// confirmación explícita con el monto a la vista.
///
/// El desglose servicio a servicio queda pendiente del módulo de citas: hasta
/// entonces se liquida contra el saldo por cobrar acumulado.
class OwnerSettlementsScreen extends ConsumerStatefulWidget {
  const OwnerSettlementsScreen({super.key});

  @override
  ConsumerState<OwnerSettlementsScreen> createState() => _OwnerSettlementsScreenState();
}

class _OwnerSettlementsScreenState extends ConsumerState<OwnerSettlementsScreen> {
  String? _settling;

  Future<void> _settle(TeamBalance b, String name) async {
    final bool ok = await _confirm(b, name);
    if (!ok || !mounted) return;

    setState(() => _settling = b.employeeId);
    try {
      await ref.read(settlementRepositoryProvider).settle(b.employeeId);
      ref.invalidate(teamBalancesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Abonado al saldo de $name')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // El motivo mas comun no es un fallo tecnico: es que no hay nada
          // aprobado. Decirlo evita que el dueño reintente cinco veces.
          const SnackBar(
            content: Text(
              'No hay servicios aprobados por liquidar. Apruébalos desde la web y vuelve a intentar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _settling = null);
    }
  }

  Future<bool> _confirm(TeamBalance b, String name) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Liquidar servicios'),
        content: Text(
          'Se abonará al saldo de $name la suma de sus servicios ya aprobados. '
          'Liquidar NO le consigna el dinero: eso ocurre al dispersar la nómina. '
          'Esta operación es irreversible y queda registrada en la auditoría.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<TeamBalance>> balances = ref.watch(teamBalancesProvider);
    final AsyncValue<List<TeamMember>> team = ref.watch(teamProvider);

    return SafeArea(
      bottom: false,
      child: balances.when(
        loading: () => const AppLoader(),
        error: (_, __) => const _Empty(
          title: 'No se pudieron cargar los saldos',
          body: 'Revisa tu conexión e inténtalo de nuevo.',
        ),
        data: (list) {
          final Map<String, TeamMember> byId = {
            for (final TeamMember m in team.valueOrNull ?? const []) m.id: m,
          };
          final List<TeamBalance> payable = list.where((b) => b.pending > 0).toList()
            ..sort((a, b) => b.pending.compareTo(a.pending));
          final double total = list.fold(0, (a, b) => a + b.pending);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(teamBalancesProvider);
              await ref.read(teamBalancesProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
              ),
              children: [
                Text('Liquidaciones', style: AppTypography.headlineLg(color: scheme.onSurface)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Confirma lo devengado para liberar comisiones.',
                  style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ---- Resumen ----
                _TotalCard(total: total, employees: payable.length),
                const SizedBox(height: AppSpacing.xl),

                Text('Pendientes', style: AppTypography.headlineMd(color: scheme.onSurface)),
                const SizedBox(height: AppSpacing.md),

                if (payable.isEmpty)
                  _Empty(
                    title: 'Nada por liquidar',
                    body: list.isEmpty
                        ? 'Aún no hay colaboradores con saldo.'
                        : 'Todo tu equipo está al día. El devengado sumará cuando entre el módulo de citas.',
                  )
                else
                  ...payable.map((b) {
                    final TeamMember? m = byId[b.employeeId];
                    final String name = m?.displayName ?? 'Colaborador';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _SettlementCard(
                        name: name,
                        branch: m?.branchName ?? 'Sin sede',
                        photoUrl: m?.photoUrl,
                        pending: b.pending,
                        accrued: b.accrued,
                        busy: _settling == b.employeeId,
                        onSettle: _settling == null ? () => _settle(b, name) : null,
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Total por confirmar: la cifra que el dueño busca al entrar.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.employees});
  final double total;
  final int employees;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        color: AppColors.ink900,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total por confirmar',
            style: AppTypography.labelMd(color: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatCOP(total), style: AppTypography.displayXl(color: Colors.white)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            employees == 1 ? '1 colaborador con saldo' : '$employees colaboradores con saldo',
            style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.name,
    required this.branch,
    required this.photoUrl,
    required this.pending,
    required this.accrued,
    required this.busy,
    required this.onSettle,
  });

  final String name;
  final String branch;
  final String? photoUrl;
  final double pending;
  final double accrued;
  final bool busy;
  final VoidCallback? onSettle;

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
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(name: name, photoUrl: photoUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMd(color: scheme.onSurface),
                    ),
                    Text(
                      branch,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCOP(pending),
                    style: AppTypography.titleMd(color: scheme.primary),
                  ),
                  Text(
                    'de ${formatCOP(accrued)}',
                    style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Abonar aprobado',
            icon: Icons.verified_outlined,
            size: AppButtonSize.sm,
            expanded: true,
            loading: busy,
            onPressed: onSettle,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final String initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      height: 48,
      width: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(
                initials,
                style: AppTypography.titleMd(color: AppColors.onPrimaryFixedVariant),
              ),
            )
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: AppTypography.titleMd(color: AppColors.onPrimaryFixedVariant),
                ),
              ),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});
  final String title;
  final String body;

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
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMd(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
