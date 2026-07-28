import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';

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

  /// Para que el host observe el foco (p. ej. la mascota en modo `typing`).
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: enabled,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
