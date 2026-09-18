import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/features/payments/cash_confirmation_card.dart';
import 'package:saas_app/features/payments/movement_receipt_sheet.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';

/// Movimientos: la PLATA. El trabajo que la genera vive en Servicios.
///
/// Hay dos direcciones y ninguna es una pérdida:
///
///  * ABONO — se le reconoció dinero (comisión o sueldo base). Ya es suyo, pero
///    todavía está en el saldo, no en su bolsillo.
///  * PAGADO — se le consignó. Su saldo baja porque el dinero SALIÓ del saldo y
///    ENTRÓ a su cuenta. Pintarlo en rojo con un menos, como un gasto, es
///    exactamente al revés de lo que pasó: es el día que cobra.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final EmployeeBalance balance = ref.watch(myBalanceProvider).valueOrNull ?? EmployeeBalance.zero;
    final AsyncValue<List<SettlementEntry>> history = ref.watch(mySettlementsProvider);
    final List<SettlementEntry> entries = history.valueOrNull ?? const [];

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myBalanceProvider);
          await ref.read(mySettlementsProvider.future);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile,
            AppSpacing.bottomForNavBar(context),
          ),
          children: [
            Text('Movimientos', style: AppTypography.headlineLg(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Toca uno para ver su comprobante.',
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Lo único que le pide algo. Va primero o no lo ve.
            CashConfirmationCard(entries: entries.where((e) => e.cashPendingConfirmation).toList()),

            _Resumen(enSaldo: balance.balance, cobrado: balance.paid),
            const SizedBox(height: AppSpacing.xl),

            history.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxl),
                child: AppLoader(),
              ),
              error: (_, __) => const _Vacio(
                titulo: 'No se pudo cargar',
                cuerpo: 'Revisa tu conexión y desliza hacia abajo para reintentar.',
              ),
              data: (list) => list.isEmpty
                  ? const _Vacio(
                      titulo: 'Todavía no tienes movimientos',
                      cuerpo: 'Cuando tu jefe apruebe tus servicios, el abono aparecerá aquí.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final _Grupo g in _agrupar(list)) _Seccion(grupo: g),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  List<_Grupo> _agrupar(List<SettlementEntry> entries) {
    final Map<String, List<SettlementEntry>> mapa = {};
    for (final SettlementEntry e in entries) {
      mapa.putIfAbsent(_etiqueta(e.settledAt), () => []).add(e);
    }
    return mapa.entries.map((e) => _Grupo(e.key, e.value)).toList();
  }

  String _etiqueta(DateTime d) {
    final DateTime hoy = DateTime.now();
    if (d.year == hoy.year && d.month == hoy.month) return 'Este mes';
    return d.year == hoy.year ? _meses[d.month - 1] : '${_meses[d.month - 1]} ${d.year}';
  }
}

class _Grupo {
  const _Grupo(this.label, this.entries);
  final String label;
  final List<SettlementEntry> entries;
}

/// Las DOS cifras que importan, y solo esas: lo que tiene guardado y lo que ya
/// cobró. Antes esto eran cuatro números repartidos entre dos tarjetas.
class _Resumen extends StatelessWidget {
  const _Resumen({required this.enSaldo, required this.cobrado});
  final double enSaldo;
  final double cobrado;

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
      child: Row(
        children: [
          Expanded(
            child: _Cifra(
              label: 'EN TU SALDO',
              value: enSaldo,
              color: scheme.primary,
              nota: 'Aún no consignado',
            ),
          ),
          Container(width: 1, height: 44, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Expanded(
            child: _Cifra(
              label: 'YA COBRADO',
              value: cobrado,
              color: scheme.onSurface,
              nota: 'Consignado a tus cuentas',
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.label, required this.value, required this.color, required this.nota});
  final String label;
  final double value;
  final Color color;
  final String nota;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSm(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatCOP(value), style: AppTypography.headlineMd(color: color)),
          ),
          const SizedBox(height: 2),
          Text(nota, style: AppTypography.labelSm(color: scheme.outline)),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.grupo});
  final _Grupo grupo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.md),
            child: Text(
              grupo.label.toUpperCase(),
              style: AppTypography.labelSm(color: scheme.onSurfaceVariant),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppElevation.card,
            ),
            child: Column(
              children: [
                for (int i = 0; i < grupo.entries.length; i++) ...[
                  _Fila(entry: grupo.entries[i]),
                  if (i < grupo.entries.length - 1)
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
    );
  }
}

/// Una fila. Qué fue, cuándo y cuánto. El desglose sale al tocarla: ponerlo
/// aquí llenaba la lista de píldoras que solo hacen falta cuando se abre.
class _Fila extends StatelessWidget {
  const _Fila({required this.entry});
  final SettlementEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool abono = entry.type.isCredit;

    return InkWell(
      onTap: () => showMovementReceipt(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                // El pago no es gris apagado ni rojo: es verde, porque es el día
                // que cobra. El abono va en el acento de la marca.
                color: abono ? AppColors.primaryFixed : AppColors.successContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Icon(
                abono ? Icons.savings_outlined : Icons.account_balance_outlined,
                size: 20,
                color: abono ? AppColors.onPrimaryFixedVariant : AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titulo(entry.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cuando(entry.settledAt),
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
                  // SIN signo menos en el pago. El dinero no se perdió: cambió
                  // de sitio, del saldo a su cuenta. Un "−" ahí es la lectura
                  // equivocada de todo el módulo.
                  abono ? '+${formatCOP(entry.amount)}' : formatCOP(entry.amount),
                  style: AppTypography.titleMd(
                    color: abono ? scheme.primary : AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  abono ? 'a tu saldo' : 'a tu cuenta',
                  style: AppTypography.labelSm(color: scheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _titulo(MovementType t) => switch (t) {
        MovementType.commission => 'Liquidación de servicios',
        MovementType.baseSalary => 'Sueldo base',
        MovementType.payroll => 'Te consignaron',
      };

  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String _cuando(DateTime d) =>
      '${d.day} ${_meses[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.titulo, required this.cuerpo});
  final String titulo;
  final String cuerpo;

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
          Text(titulo, textAlign: TextAlign.center,
              style: AppTypography.titleMd(color: scheme.onSurface),),
          const SizedBox(height: AppSpacing.xs),
          Text(cuerpo, textAlign: TextAlign.center,
              style: AppTypography.bodySm(color: scheme.onSurfaceVariant),),
        ],
      ),
    );
  }
}
