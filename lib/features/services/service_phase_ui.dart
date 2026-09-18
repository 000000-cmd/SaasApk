import 'package:flutter/material.dart';
import 'package:saas_app/core/finance/service_charge_repository.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';

/// Cómo se llama y de qué color va cada fase, en UN solo sitio.
///
/// La misma fase la pintan la lista, el detalle y el resumen de Inicio. Con tres
/// copias, tarde o temprano un servicio se llama "Por aprobar" en una pantalla y
/// "Pendiente" en otra, y quien lo lee cree que son dos cosas.
extension ServicePhaseUi on ServicePhase {
  String get label => switch (this) {
        ServicePhase.porConfirmar => 'Sin confirmar',
        ServicePhase.agendado => 'Agendado',
        // "Hoy" y no "Por realizar": dice CUÁNDO, que es el dato que hace
        // actuar. Una orden en una etiqueta de estado se lee como un regaño.
        ServicePhase.hoy => 'Hoy',
        ServicePhase.enCurso => 'En curso',
        ServicePhase.porAprobar => 'Por aprobar',
        ServicePhase.aprobado => 'Aprobado',
        ServicePhase.abonado => 'En tu saldo',
        ServicePhase.rechazado => 'Rechazado',
        ServicePhase.cancelado => 'No se hizo',
      };

  AppTagTone get tone => switch (this) {
        ServicePhase.porConfirmar => AppTagTone.warning,
        ServicePhase.agendado => AppTagTone.neutral,
        ServicePhase.hoy => AppTagTone.primary,
        ServicePhase.enCurso => AppTagTone.primary,
        ServicePhase.porAprobar => AppTagTone.warning,
        ServicePhase.aprobado => AppTagTone.primary,
        ServicePhase.abonado => AppTagTone.success,
        ServicePhase.rechazado => AppTagTone.danger,
        ServicePhase.cancelado => AppTagTone.neutral,
      };

  IconData get icon => switch (this) {
        ServicePhase.porConfirmar => Icons.help_outline_rounded,
        ServicePhase.agendado => Icons.event_outlined,
        ServicePhase.hoy => Icons.today_rounded,
        ServicePhase.enCurso => Icons.play_arrow_rounded,
        ServicePhase.porAprobar => Icons.hourglass_top_rounded,
        ServicePhase.aprobado => Icons.check_rounded,
        ServicePhase.abonado => Icons.savings_outlined,
        ServicePhase.rechazado => Icons.close_rounded,
        ServicePhase.cancelado => Icons.event_busy_outlined,
      };

  /// Qué significa, en una frase y sin jerga. Va en el detalle, no en la lista.
  String get explicacion => switch (this) {
        ServicePhase.porConfirmar =>
          'El cliente la pidió y el negocio todavía no la ha aceptado. Cuando la acepten, aparece en tu día.',
        ServicePhase.agendado =>
          'Todavía no toca. El día de la cita podrás empezarla desde aquí.',
        ServicePhase.hoy =>
          'Es de hoy. Cuando el cliente llegue, dale a empezar.',
        ServicePhase.enCurso =>
          'La estás atendiendo. Cuando acabes, dale a terminar y entra a revisión.',
        ServicePhase.porAprobar =>
          'Ya la terminaste. Tu jefe la está revisando; cuando la apruebe, el valor pasa a tu saldo.',
        ServicePhase.aprobado =>
          'Aprobado. Entra en tu próxima liquidación y ahí se suma a tu saldo.',
        ServicePhase.abonado =>
          'Este valor ya está en tu saldo. Se te consigna en la próxima nómina.',
        ServicePhase.rechazado =>
          'Tu jefe no aprobó este servicio, así que no se paga. Queda registrado con su motivo.',
        ServicePhase.cancelado =>
          'Esta cita no se prestó. No se paga, pero queda en el historial con lo que pasó.',
      };
}
