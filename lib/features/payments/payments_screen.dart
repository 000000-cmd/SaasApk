import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';

/// Historial de pagos del empleado (pantalla "Historial de Servicios" del
/// sistema): acumulado arriba y los movimientos agrupados por periodo.
///
/// Son datos REALES: cada fila es una liquidación confirmada por el dueño,
/// leída de la auditoría de tesorería en finance-service. El desglose servicio
/// a servicio dentro de cada pago llegará con el módulo de citas.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EmployeeBalance balance = ref.watch(myBalanceProvider).valueOrNull ?? EmployeeBalance.zero;
    final AsyncValue<List<SettlementEntry>> history = ref.watch(mySettlementsProvider);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myBalanceProvider);
          await ref.read(mySettlementsProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
          ),
          children: [
            Text('Pagos', style: AppTypography.headlineLg(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cada pago que recibas queda registrado aquí.',
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Acumulado ----
            _TotalCard(paid: balance.paid, pending: balance.balance),
            const SizedBox(height: AppSpacing.xl),

            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: AppLoader(),
              ),
              error: (_, __) => const _Empty(
                title: 'No se pudo cargar el historial',
                body: 'Revisa tu conexión e inténtalo de nuevo.',
              ),
              data: (entries) => entries.isEmpty
                  ? const _Empty(
                      title: 'Aún no tienes pagos registrados',
                      body: 'Cuando tu empleador libere una comisión, aparecerá aquí con su detalle.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _groups(entries)
                          .map((g) => _PeriodSection(label: g.label, entries: g.entries))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Agrupa por mes, de lo más reciente a lo más viejo (el diseño separa por
  /// periodo con su contador al lado).
  List<_Group> _groups(List<SettlementEntry> entries) {
    final Map<String, List<SettlementEntry>> byPeriod = {};
    for (final SettlementEntry e in entries) {
      byPeriod.putIfAbsent(_periodLabel(e.settledAt), () => []).add(e);
    }
    return byPeriod.entries.map((e) => _Group(e.key, e.value)).toList();
  }

  static const List<String> _months = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  String _periodLabel(DateTime d) {
    final DateTime now = DateTime.now();
    if (d.year == now.year && d.month == now.month) return 'Este mes';
    final String month = _months[d.month - 1];
    return d.year == now.year ? month : '$month ${d.year}';
  }
}

class _Group {
  const _Group(this.label, this.entries);
  final String label;
  final List<SettlementEntry> entries;
}

/// Acumulado: lo cobrado hasta hoy + lo que sigue pendiente.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.paid, required this.pending});
  final double paid;
  final double pending;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTAL COBRADO', style: AppTypography.labelSm(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatCOP(paid), style: AppTypography.displayXl(color: scheme.primary)),
                ),
              ),
              if (pending > 0)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '+${formatCOP(pending)} en camino',
                      style: AppTypography.labelSm(color: AppColors.onPrimaryFixedVariant),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bloque de un periodo: encabezado con contador + tarjeta con las filas.
class _PeriodSection extends StatelessWidget {
  const _PeriodSection({required this.label, required this.entries});
  final String label;
  final List<SettlementEntry> entries;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
                  ),
                ),
                Text(
                  entries.length == 1 ? '1 pago' : '${entries.length} pagos',
                  style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppElevation.card,
            ),
            child: Column(
              children: [
                for (int i = 0; i < entries.length; i++) ...[
                  _PaymentRow(entry: entries[i]),
                  if (i < entries.length - 1)
                    Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.entry});
  final SettlementEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppColors.onPrimaryFixedVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comisión liberada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMd(color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      formatCOP(entry.amount),
                      style: AppTypography.titleMd(color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.note?.trim().isNotEmpty == true ? entry.note!.trim() : 'Liquidación',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _stamp(entry.settledAt),
                      style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _stamp(DateTime d) {
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · $hh:$mm';
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
          Icon(Icons.receipt_long_outlined, size: 28, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
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
