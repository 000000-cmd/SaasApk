import 'package:flutter/material.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/shared/util/input_masks.dart';

/// Campo de fecha con DOS caminos: teclearla o elegirla en el calendario.
///
/// Escribirla suele ser más rápido — una fecha de nacimiento está a 8 pulsaciones
/// y el calendario obliga a navegar décadas hacia atrás. Por eso el campo es lo
/// principal (con máscara `dd/mm/aaaa` puesta al vuelo) y el calendario es un
/// botón al lado, no el único acceso.
///
/// Debajo se confirma la fecha en palabras ("4 de marzo de 1990"): al teclear
/// es fácil bailar el día con el mes, y verla escrita lo delata.
class AppDateField extends StatefulWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.initialPickerDate,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Dónde abre el calendario cuando no hay nada escrito (p. ej. hace 25 años
  /// para una fecha de nacimiento: ahorra décadas de scroll).
  final DateTime? initialPickerDate;
  final String? helper;

  @override
  State<AppDateField> createState() => _AppDateFieldState();
}

class _AppDateFieldState extends State<AppDateField> {
  late final TextEditingController _controller =
      TextEditingController(text: DateText.format(widget.value));
  String? _error;

  @override
  void didUpdateWidget(AppDateField old) {
    super.didUpdateWidget(old);
    // Si el valor cambia desde fuera (p. ej. el calendario), refleja el texto,
    // pero sin pisar lo que el usuario esté tecleando.
    if (widget.value != old.value && widget.value != DateText.parse(_controller.text)) {
      _controller.text = DateText.format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  DateTime get _first => widget.firstDate ?? DateTime(DateTime.now().year - 100);
  DateTime get _last => widget.lastDate ?? DateTime.now();

  void _onText(String raw) {
    final String digits = InputMasks.digitsOnly(raw);
    if (digits.isEmpty) {
      setState(() => _error = null);
      widget.onChanged(null);
      return;
    }
    // Mientras no estén los 8 dígitos no se regaña: el usuario sigue escribiendo.
    if (digits.length < 8) {
      setState(() => _error = null);
      return;
    }
    final DateTime? parsed = DateText.parse(raw);
    if (parsed == null) {
      setState(() => _error = 'Esa fecha no existe');
      widget.onChanged(null);
      return;
    }
    if (parsed.isBefore(_first) || parsed.isAfter(_last)) {
      setState(() => _error = 'Fuera de rango');
      widget.onChanged(null);
      return;
    }
    setState(() => _error = null);
    widget.onChanged(parsed);
  }

  Future<void> _pick() async {
    FocusScope.of(context).unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? widget.initialPickerDate ?? _last,
      firstDate: _first,
      lastDate: _last,
      // El calendario sale en español gracias a los delegates de MaterialApp.
      helpText: 'Elige la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Listo',
      fieldLabelText: 'Fecha',
    );
    if (picked == null) return;
    _controller.text = DateText.format(picked);
    setState(() => _error = null);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool hasError = _error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTypography.labelMd(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          onChanged: _onText,
          keyboardType: TextInputType.number,
          inputFormatters: InputMasks.date(),
          style: AppTypography.bodyLg(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'dd/mm/aaaa',
            errorText: _error,
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: hasError ? scheme.error : scheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              borderSide: BorderSide(color: hasError ? scheme.error : AppColors.primary, width: 2),
            ),
            suffixIcon: IconButton(
              onPressed: _pick,
              icon: const Icon(Icons.calendar_month_rounded),
              tooltip: 'Abrir calendario',
              color: AppColors.primary,
            ),
          ),
        ),
        // Confirmación en palabras: delata un día y un mes intercambiados.
        if (_error == null && widget.value != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  DateText.long(widget.value),
                  style: AppTypography.labelMd(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ] else if (_error == null && widget.helper != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(widget.helper!, style: AppTypography.labelMd(color: scheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}
