import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_button.dart';

/// Aviso de que te pagaron EN EFECTIVO y todavía no lo has confirmado.
///
/// Existe porque una transferencia deja comprobante y el efectivo no deja nada.
/// Sin este acuse, "ya te pagué" es la palabra del dueño contra la del
/// colaborador, y el saldo ya bajó — así que el que tiene algo que perder si
/// nadie firma es el colaborador.
///
/// Va arriba del todo y en color de alerta a propósito: no es una notificación
/// más, es plata que alguien dice haberte entregado.
class CashConfirmationCard extends ConsumerStatefulWidget {
  const CashConfirmationCard({super.key, required this.entries});

  /// Los pagos en efectivo sin acusar, del más reciente al más viejo.
  final List<SettlementEntry> entries;

  @override
  ConsumerState<CashConfirmationCard> createState() => _CashConfirmationCardState();
}

class _CashConfirmationCardState extends ConsumerState<CashConfirmationCard> {
  String? _confirming;

  Future<void> _confirm(SettlementEntry e) async {
    final String? employeeId = ref.read(myBalanceProvider).valueOrNull?.employeeId;
    if (employeeId == null) return;

    final bool ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar que recibiste el dinero'),
            content: Text(
              'Vas a dejar constancia de que recibiste ${formatCOP(e.amount)} en efectivo. '
              'Hazlo solo si ya tienes la plata en la mano: después no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Todavía no'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí, lo recibí'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;

    setState(() => _confirming = e.id);
    try {
      await ref.read(settlementRepositoryProvider).confirmCash(e.id, employeeId);
      ref.invalidate(mySettlementsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias. Quedó registrado que lo recibiste.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo confirmar. Inténtalo de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.onErrorContainer, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.entries.length == 1
                      ? 'Te pagaron en efectivo'
                      : 'Tienes ${widget.entries.length} pagos en efectivo',
                  style: AppTypography.titleMd(color: AppColors.onErrorContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Tu empleador registró que te entregó este dinero en mano. Confirma que lo '
            'recibiste para dejarlo por escrito.',
            style: AppTypography.bodySm(color: AppColors.onErrorContainer),
          ),
          const SizedBox(height: AppSpacing.lg),

          for (final SettlementEntry e in widget.entries) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatCOP(e.amount),
                          style: AppTypography.headlineMd(color: scheme.onSurface),
                        ),
                      ),
                      Text(
                        _stamp(e.settledAt),
                        style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (e.hasBaseSalary) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Comisión ${formatCOP(e.commissionAmount)}'
                      ' + sueldo base ${formatCOP(e.baseSalaryAmount)}',
                      style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Confirmo que lo recibí',
                    icon: Icons.check_circle_outline,
                    size: AppButtonSize.sm,
                    expanded: true,
                    loading: _confirming == e.id,
                    onPressed: _confirming == null ? () => _confirm(e) : null,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _stamp(DateTime d) {
    final String dd = d.day.toString().padLeft(2, '0');
    final String mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
