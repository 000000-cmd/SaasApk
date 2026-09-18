import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/finance/settlement_repository.dart';
import 'package:saas_app/shared/util/money.dart';

/// Comprobante de un movimiento: la vista tipo factura al tocar una fila.
///
/// Se abre como hoja y no como pantalla porque un comprobante siempre se mira
/// DESDE la lista y se cierra volviendo a ella.
///
/// El desglose llega CONGELADO del back. Recalcularlo aquí daría otro número
/// meses después, cuando la compensación de esa persona ya sea otra.
Future<void> showMovementReceipt(BuildContext context, SettlementEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MovementReceiptSheet(entry: entry),
  );
}

class _MovementReceiptSheet extends ConsumerStatefulWidget {
  const _MovementReceiptSheet({required this.entry});
  final SettlementEntry entry;

  @override
  ConsumerState<_MovementReceiptSheet> createState() => _MovementReceiptSheetState();
}

class _MovementReceiptSheetState extends ConsumerState<_MovementReceiptSheet> {
  bool _bajando = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final SettlementEntry e = widget.entry;
    final bool abono = e.type.isCredit;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg,
                ),
                children: [
                  Text(_titulo(e.type), style: AppTypography.headlineMd(color: scheme.onSurface)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_sello(e.settledAt), style: AppTypography.bodySm(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.xl),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: abono ? AppColors.primaryFixed : AppColors.successContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Text(
                          abono ? 'ABONADO A TU SALDO' : 'CONSIGNADO A TU CUENTA',
                          style: AppTypography.labelSm(
                            color: abono ? AppColors.onPrimaryFixedVariant : AppColors.success,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            // Sin menos: el dinero no se perdió, salió del saldo
                            // y entró a su cuenta. Es el día que cobra.
                            formatCOP(e.amount),
                            style: AppTypography.displayXl(
                              color: abono ? AppColors.onPrimaryFixed : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  if (e.type == MovementType.payroll) ...[
                    _Row(label: 'Comisión por servicios', value: formatCOP(e.commissionAmount)),
                    if (e.hasBaseSalary)
                      _Row(
                        label: 'Sueldo base del periodo',
                        value: formatCOP(e.baseSalaryAmount),
                        destacado: true,
                      ),
                    _Row(
                      label: 'Cuenta destino',
                      value: (e.payoutAccount?.trim().isNotEmpty ?? false)
                          ? e.payoutAccount!.trim()
                          : 'Consignación directa',
                    ),
                  ],
                  _Row(label: 'Tu saldo quedó en', value: formatCOP(e.balanceAfter)),
                  if ((e.note ?? '').trim().isNotEmpty)
                    _Row(label: 'Nota', value: e.note!.trim()),

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    abono
                        ? 'Este monto ya es tuyo y está en tu saldo. Se te consigna en la próxima nómina.'
                        : 'Constancia interna del pago. Tu negocio no opera con el banco desde la app, '
                            'así que este movimiento no tiene número de transacción bancaria.',
                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                  ),

                  // El papel, para guardarlo o mandarlo. Solo en los pagos: un
                  // abono todavía no es un comprobante de nada.
                  if (e.type == MovementType.payroll) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                        ),
                        onPressed: _bajando ? null : _descargar,
                        icon: _bajando
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded, size: 19),
                        label: Text(_bajando ? 'Bajando…' : 'Descargar comprobante'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'El PDF va protegido: la contraseña es tu número de documento, '
                      'sin puntos ni espacios.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm(color: scheme.outline),
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

  /// Baja el extracto y lo abre con el visor del teléfono.
  ///
  /// Se guarda en el directorio temporal a propósito: es una copia para mirar o
  /// compartir, y el original siempre se puede volver a pedir. Llenarle el
  /// almacenamiento con PDFs que él no gestiona sería quedarse con su espacio.
  Future<void> _descargar() async {
    setState(() => _bajando = true);
    try {
      final Response<dynamic> res = await ref.read(apiClientProvider).dio.get<dynamic>(
            'finance/payroll/movements/${widget.entry.id}/statement',
            options: Options(responseType: ResponseType.bytes),
          );
      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/comprobante-${widget.entry.id}.pdf');
      await file.writeAsBytes(List<int>.from(res.data as List<dynamic>));
      await OpenFilex.open(file.path);
      if (mounted) setState(() => _bajando = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bajando = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('No se pudo bajar el comprobante.')));
    }
  }

  static String _titulo(MovementType t) => switch (t) {
        MovementType.commission => 'Liquidación de servicios',
        MovementType.baseSalary => 'Sueldo base del periodo',
        MovementType.payroll => 'Te consignaron',
      };

  static String _sello(DateTime d) {
    const List<String> meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final String hh = d.hour.toString().padLeft(2, '0');
    final String mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} de ${meses[d.month - 1]} de ${d.year} · $hh:$mm';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.destacado = false});
  final String label;
  final String value;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTypography.bodySm(color: scheme.onSurfaceVariant))),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: destacado
                  ? AppTypography.titleMd(color: scheme.primary)
                  : AppTypography.bodyMd(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
