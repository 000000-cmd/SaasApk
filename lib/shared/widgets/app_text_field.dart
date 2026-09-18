import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/shared/util/masks.dart';

/// Campo de texto del design system: label + input (tema) + error.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscure = false,
    this.keyboardType,
    this.errorText,
    this.suffixIcon,
    this.enabled = true,
    this.onSubmitted,
    this.textInputAction,
    this.focusNode,
    this.inputFormatters,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.mask,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? errorText;
  final Widget? suffixIcon;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Máscaras / filtros de entrada (número de documento, celular…).
  final List<TextInputFormatter>? inputFormatters;

  /// Tope de caracteres. Se pinta SIN el contador de Material: el "0/40" bajo
  /// cada campo llena el formulario de ruido y solo importa cuando ya estorba,
  /// que es justo cuando el campo deja de aceptar más y se nota solo.
  final int? maxLength;

  /// Mayúscula automática. En nombres ahorra el gesto de siempre; en un número
  /// de cuenta o una llave BREV estorbaría, así que no se pone por defecto.
  final TextCapitalization textCapitalization;

  /// Para que el host observe el foco (p. ej. la mascota en modo `typing`).
  final FocusNode? focusNode;

  /// Máscara del estándar (`lib/shared/util/masks.dart`), el MISMO id que usa
  /// la web. Aporta de una vez el formateo, el teclado correcto, el tope de
  /// caracteres y el ejemplo en el hint, así que declarar el tipo de dato basta.
  ///
  /// Regla del proyecto: ante cada campo nuevo, la pregunta es "¿este dato
  /// tiene forma?". Si la tiene, lleva máscara; sólo el texto libre no.
  final MaskId? mask;

  @override
  Widget build(BuildContext context) {
    final MaskSpec? spec = mask == null ? null : kMasks[mask];
    // Lo que se declara a mano manda; la máscara solo rellena los huecos.
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      if (spec != null) MaskFormatter(mask!),
      ...?inputFormatters,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          // La etiqueta "flota" sobre el campo, en el estilo label del sistema.
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Text(
              label!,
              style: AppTypography.labelMd(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType ?? spec?.keyboard,
          inputFormatters: formatters.isEmpty ? null : formatters,
          maxLength: maxLength ?? spec?.maxLength,
          textCapitalization: textCapitalization,
          enabled: enabled,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint ?? spec?.placeholder,
            errorText: errorText,
            suffixIcon: suffixIcon,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
