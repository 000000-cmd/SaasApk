import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/business/agenda_repository.dart';
import 'package:saas_app/core/finance/service_charge_repository.dart';
import 'package:saas_app/features/services/service_phase_ui.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';

/// El detalle de un servicio: TODO lo que la fila de la lista no dice.
///
/// La lista muestra lo mínimo para reconocerlo (hora, servicio, cuánto). Aquí
/// está el resto: el cliente, cómo pagó, cuánto se queda el negocio y en qué
/// punto del ciclo va. Repetirlo arriba sería llenar la lista de datos que
/// nadie lee hasta que abre.
Future<void> showServiceDetail(BuildContext context, ServiceItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ServiceDetailSheet(item: item),
  );
}

class _ServiceDetailSheet extends ConsumerStatefulWidget {
  const _ServiceDetailSheet({required this.item});
  final ServiceItem item;

  @override
  ConsumerState<_ServiceDetailSheet> createState() => _ServiceDetailSheetState();
}

class _ServiceDetailSheetState extends ConsumerState<_ServiceDetailSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final ServiceItem s = widget.item;
    final ServicePhase phase = s.phase;

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(s.serviceName, style: AppTypography.headlineMd(color: scheme.onSurface)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      AppTag(label: phase.label, tone: phase.tone),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _cuando(s),
                    style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Lo que se lleva él, que es lo que viene a mirar.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.primaryFixed,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Text(
                          // Sin cargo todavía no hay comisión calculada, así
                          // que lo que se enseña es el precio. Llamarlo "te
                          // queda" sería prometer el total.
                          !s.tieneCargo
                              ? 'PRECIO DEL SERVICIO'
                              : (phase == ServicePhase.abonado ? 'TE QUEDÓ' : 'TE QUEDA'),
                          style: AppTypography.labelSm(color: AppColors.onPrimaryFixedVariant),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatCOP(s.montoVisible),
                            style: AppTypography.displayXl(color: AppColors.onPrimaryFixed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  _Row(label: 'Cliente', value: s.clientName),
                  if ((s.clientPhone ?? '').isNotEmpty) _Row(label: 'Teléfono', value: s.clientPhone!),
                  _Row(label: 'Cobrado al cliente', value: formatCOP(s.grossAmount)),
                  if (s.tieneCargo) ...[
                    _Row(
                      label: 'Se queda el negocio (${s.deductionRate.round()}%)',
                      value: formatCOP(s.grossAmount - s.netAmount),
                    ),
                    _Row(label: 'Forma de pago', value: _medio(s.paymentMethod)),
                  ],
                  if ((s.discardReason ?? '').isNotEmpty)
                    _Row(label: 'Motivo del rechazo', value: s.discardReason!),

                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    phase.explicacion,
                    style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                  ),

                  // Las acciones del empleado sobre su trabajo. Salen de la
                  // máquina de estados de la cita —la misma que valida el
                  // servidor—, así que solo aparece lo que de verdad se puede
                  // hacer ahora: un botón que a veces no hace nada enseña a no
                  // confiar en los botones.
                  if (_accion != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                        ),
                        onPressed: _saving ? null : () => _mover(_accion!),
                        child: _saving
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_accion!.etiqueta),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _accion!.ayuda,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
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

  /// Lo que se puede hacer AHORA con esta cita, o nada.
  ///
  /// Terminar sin haber empezado no está: la agenda no lo admite, y no es una
  /// formalidad — es lo que distingue "el cliente llegó y no vino nadie más" de
  /// "cerré la cita al final del día sin acordarme de qué pasó".
  _Accion? get _accion => switch (widget.item.phase) {
        ServicePhase.hoy => const _Accion(
            estado: 'EN_CURSO',
            etiqueta: 'Empezar el servicio',
            ayuda: 'Dale cuando el cliente llegue y empieces a atenderlo.',
            hecho: 'Empezaste el servicio.',
          ),
        ServicePhase.enCurso => const _Accion(
            estado: 'COMPLETADA',
            etiqueta: 'Marcar como terminado',
            ayuda: 'Al terminarlo, tu jefe lo revisa y el valor pasa a tu saldo.',
            hecho: 'Listo. Queda esperando aprobación.',
          ),
        _ => null,
      };

  Future<void> _mover(_Accion accion) async {
    final String? citaId = widget.item.appointmentId;
    if (citaId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(agendaRepositoryProvider).changeStatus(citaId, accion.estado);
      // El saldo cambia cuando el dueño aprueba, no ahora; pero la lista de
      // servicios sí, y con ella los cargos que la sincronización acaba de
      // crear.
      ref.invalidate(myServicesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(accion.hecho)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(_motivo(e))));
    }
  }

  /// El mensaje del servidor cuando lo trae: nueve de cada diez veces dice que
  /// otra persona movió la cita antes, y eso es la respuesta, no "revisa tu
  /// conexión".
  static String _motivo(Object e) {
    if (e is DioException) {
      final dynamic cuerpo = e.response?.data;
      if (cuerpo is Map && cuerpo['message'] is String) return cuerpo['message'] as String;
    }
    return 'No se pudo. Revisa tu conexión.';
  }

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String _cuando(ServiceItem s) {
    final String fecha = '${s.serviceDate.day} de ${_meses[s.serviceDate.month - 1]}';
    final String? franja = s.franja;
    return franja == null ? fecha : '$fecha · $franja';
  }

  static String _medio(String raw) => switch (raw) {
        'CASH' => 'Efectivo',
        'TRANSFER' => 'Transferencia',
        'CARD' => 'Tarjeta',
        _ => raw,
      };
}

/// Una acción sobre la cita: a qué estado la lleva y cómo se cuenta.
class _Accion {
  const _Accion({
    required this.estado,
    required this.etiqueta,
    required this.ayuda,
    required this.hecho,
  });

  /// El estado del dominio. Es el mismo nombre que valida el servidor.
  final String estado;
  final String etiqueta;
  final String ayuda;
  final String hecho;
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

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
              style: AppTypography.bodyMd(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
