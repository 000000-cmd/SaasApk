import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/shared/util/input_masks.dart';
import 'package:saas_app/shared/widgets/app_button.dart';
import 'package:saas_app/shared/widgets/app_date_field.dart';
import 'package:saas_app/shared/widgets/app_text_field.dart';
import 'package:saas_app/shared/widgets/orb_mascot.dart';

/// Primer ingreso del empleado: el dueño creó la cuenta (tercero y empleado
/// nacieron como shells vacíos); aquí el empleado completa sus datos en un
/// wizard de 3 pasos antes de entrar al panel. El ORB lo acompaña arriba y el
/// avance es visible en todo momento — un paso, una pregunta.
///
/// TODO(back): persistir estos datos en el servicio de empleados/terceros y
/// marcar el perfil como completado server-side (hoy el flag es local).
class EmployeeOnboardingScreen extends ConsumerStatefulWidget {
  const EmployeeOnboardingScreen({super.key});

  @override
  ConsumerState<EmployeeOnboardingScreen> createState() => _EmployeeOnboardingScreenState();
}

class _EmployeeOnboardingScreenState extends ConsumerState<EmployeeOnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _document = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  late final List<FocusNode> _focuses = List.generate(4, (_) => FocusNode());
  final OrbMascotController _mascot = OrbMascotController();
  DateTime? _birthDate;
  /// Tipo de documento: precargado en cédula de ciudadanía, pero modificable.
  String _docType = 'CC';
  static const Map<String, String> _docTypes = {
    'CC': 'Cédula de ciudadanía',
    'CE': 'Cédula de extranjería',
    'TI': 'Tarjeta de identidad',
    'PA': 'Pasaporte',
    'NIT': 'NIT',
  };
  int _step = 0;
  bool _saving = false;
  bool _typing = false;
  String? _error;

  static const List<String> _eyebrows = ['IDENTIDAD', 'CONTACTO', 'CONFIRMACIÓN'];
  static const List<String> _titles = ['¿Quién eres?', '¿Cómo te contactamos?', 'Todo listo'];

  @override
  void initState() {
    super.initState();
    for (final FocusNode f in _focuses) {
      f.addListener(_syncTyping);
    }
    final String? full = ref.read(authControllerProvider).user?.fullName;
    if (full != null && full.isNotEmpty) {
      final List<String> parts = full.split(' ');
      _firstName.text = parts.first;
      if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    }
  }

  /// La mascota "escribe" mientras algún campo tenga el foco (estándar web).
  void _syncTyping() {
    final bool typing = _focuses.any((f) => f.hasFocus);
    if (typing != _typing) setState(() => _typing = typing);
  }

  @override
  void dispose() {
    for (final FocusNode f in _focuses) {
      f.dispose();
    }
    _pages.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _document.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() {
      _error = null;
      _step = step;
    });
    _pages.animateToPage(step,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic,);
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 0 &&
        (_firstName.text.trim().isEmpty ||
            _lastName.text.trim().isEmpty ||
            _document.text.trim().isEmpty)) {
      _mascot.reject();
      setState(() => _error = 'Completa nombre, apellido y documento para seguir.');
      return;
    }
    if (_step < 2) {
      _mascot.jump();
      _goTo(_step + 1);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    // La celebración se alcanza a ver antes de que el router nos saque.
    _mascot.celebrate();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // TODO(back): enviar los datos capturados al servicio de empleados.
    await ref.read(authControllerProvider.notifier).completeOnboarding();
  }


  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color sheet = dark ? AppColors.backgroundDark : AppColors.background;

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Cabecera: orb acompañante + paso + avance ----
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      OrbMascot(
                        size: 96,
                        typing: _typing,
                        loading: _saving,
                        controller: _mascot,
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PASO ${_step + 1} DE 3 · ${_eyebrows[_step]}',
                              style: AppTypography.labelSm(color: AppColors.secondaryFixedDim),
                            ),
                            const SizedBox(height: 4),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                _titles[_step],
                                key: ValueKey<int>(_step),
                                style: AppTypography.headlineLg(color: AppColors.inverseOnSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: List<Widget>.generate(3, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? AppSpacing.sm : 0),
                          decoration: BoxDecoration(
                            color: i <= _step ? AppColors.primaryContainer : AppColors.outlineDark,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          // ---- Hoja: el paso activo ----
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: sheet,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepWrap(_identityStep()),
                        _stepWrap(_contactStep()),
                        _stepWrap(_summaryStep(dark)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Text(_error!, style: AppTypography.bodySm(color: AppColors.error)),
                          ),
                        Row(
                          children: [
                            if (_step > 0) ...[
                              AppButton(
                                label: 'Atrás',
                                variant: AppButtonVariant.ghost,
                                size: AppButtonSize.lg,
                                onPressed: _saving ? null : () => _goTo(_step - 1),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              child: AppButton(
                                label: _step == 2 ? 'Empezar' : 'Continuar',
                                size: AppButtonSize.lg,
                                loading: _saving,
                                expanded: true,
                                onPressed: _next,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepWrap(Widget child) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: child,
      );

  Widget _identityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHint(text: 'Así te verá tu equipo y así quedarás en la nómina.'),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: 'Nombre',
                controller: _firstName,
                focusNode: _focuses[0],
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: 'Apellido',
                controller: _lastName,
                focusNode: _focuses[1],
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Tipo de documento',
          style: AppTypography.labelMd(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _docType,
          isExpanded: true, // evita overflow con nombres largos ("Cédula de ciudadanía")
          items: _docTypes.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ),)
              .toList(),
          onChanged: (v) => setState(() => _docType = v ?? 'CC'),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Número de documento',
          hint: 'Solo números',
          controller: _document,
          focusNode: _focuses[2],
          keyboardType: TextInputType.number,
          inputFormatters: InputMasks.document(),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _contactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHint(text: 'Para avisarte de tus citas y tus pagos. Puedes completarlo después.'),
        const SizedBox(height: AppSpacing.xl),
        AppTextField(
          label: 'Teléfono',
          hint: '300 000 0000',
          controller: _phone,
          focusNode: _focuses[3],
          keyboardType: TextInputType.phone,
          inputFormatters: InputMasks.phoneCo(),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppDateField(
          label: 'Fecha de nacimiento',
          value: _birthDate,
          // Nadie que use esto tiene 3 años ni 120: acotar el rango evita
          // teclear un año imposible y deja el calendario en un sitio útil.
          firstDate: DateTime(DateTime.now().year - 90),
          lastDate: DateTime.now(),
          initialPickerDate: DateTime(DateTime.now().year - 25),
          helper: 'Escríbela o ábrela en el calendario.',
          onChanged: (d) => setState(() => _birthDate = d),
        ),
      ],
    );
  }

  Widget _summaryStep(bool dark) {
    final Color border = dark ? AppColors.outlineVariantDark : AppColors.outlineVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHint(text: 'Revisa que todo esté bien. Desde tu perfil podrás ajustar el resto cuando quieras.'),
        const SizedBox(height: AppSpacing.xl),
        Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.surfaceContainerLowDark : AppColors.surfaceContainerLowest,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          child: Column(
            children: [
              _summaryRow('Nombre', '${_firstName.text} ${_lastName.text}'.trim(), border),
              _summaryRow('Documento', '${_docTypes[_docType]}: ${_document.text.trim()}', border),
              _summaryRow('Teléfono', _phone.text.trim(), border),
              // En el resumen la fecha va en palabras: es el último punto para
              // detectar un día y un mes cambiados antes de guardar.
              _summaryRow('Nacimiento', DateText.long(_birthDate), border, last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, Color border, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTypography.bodySm(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Sin diligenciar' : value,
              // Lo pendiente se distingue en cursiva y apagado; lo diligenciado
              // va en semibold sobre el color de texto normal.
              style: AppTypography.bodySm(
                color: value.isEmpty
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.onSurface,
              ).copyWith(
                fontWeight: value.isEmpty ? FontWeight.w400 : FontWeight.w600,
                fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ayuda corta bajo el título del paso: guía sin estorbar.
class _StepHint extends StatelessWidget {
  const _StepHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.bodyMd(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}
