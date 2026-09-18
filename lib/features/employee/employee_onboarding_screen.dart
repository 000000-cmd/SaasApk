import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/finance/bank_account_repository.dart';
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

  // ---- Paso de cuenta bancaria ----
  // Es OBLIGATORIO: sin una cuenta, el día de pago el dueño sólo puede darle
  // efectivo o perseguirlo por WhatsApp. Pedirlo aquí, una vez, cuesta menos
  // que pedirlo cada quincena.
  AccountKind _accountKind = AccountKind.bank;
  final TextEditingController _accountNumber = TextEditingController();
  final TextEditingController _brevKey = TextEditingController();
  String? _bankId;
  String _accountType = 'SAVINGS';
  List<BankOption> _banks = const [];

  static const List<String> _eyebrows = ['IDENTIDAD', 'CONTACTO', 'PAGOS', 'CONFIRMACIÓN'];
  static const List<String> _titles = [
    '¿Quién eres?', '¿Cómo te contactamos?', '¿Dónde te pagamos?', 'Todo listo',
  ];
  static const int _lastStep = 3;

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
    _loadBanks();
  }

  /// El catálogo de bancos se pide al entrar y no al llegar al paso: si falla la
  /// red, el empleado se entera antes de haber tecleado nada.
  Future<void> _loadBanks() async {
    try {
      final List<BankOption> banks = await ref.read(bankAccountRepositoryProvider).banks();
      if (mounted) setState(() => _banks = banks);
    } catch (_) {
      // Sin catálogo todavía puede registrar una llave BREV.
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
    _accountNumber.dispose();
    _brevKey.dispose();
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
    // La cuenta es obligatoria: se comprueba aquí y otra vez en el back.
    if (_step == 2) {
      final String? falta = _faltaEnCuenta();
      if (falta != null) {
        _mascot.reject();
        setState(() => _error = falta);
        return;
      }
    }
    if (_step < _lastStep) {
      _mascot.jump();
      _goTo(_step + 1);
    } else {
      _finish();
    }
  }

  /// Qué le falta a la cuenta para servir. Null = está completa.
  String? _faltaEnCuenta() {
    if (_accountKind == AccountKind.brev) {
      return _brevKey.text.trim().isEmpty ? 'Escribe tu llave BREV para poder pagarte.' : null;
    }
    if (_bankId == null) return 'Elige tu banco.';
    if (_accountNumber.text.trim().isEmpty) return 'Escribe tu número de cuenta.';
    return null;
  }

  Future<void> _finish() async {
    setState(() { _saving = true; _error = null; });

    // La cuenta SÍ se persiste (a diferencia del resto del wizard, que todavía
    // es local): es de lo que depende que le puedan pagar, y perderla obligaría
    // a pedírsela otra vez el día de la nómina.
    try {
      final String? thirdPartyId = await ref.read(myThirdPartyIdProvider.future);
      if (thirdPartyId != null) {
        await ref.read(bankAccountRepositoryProvider).create(
              thirdPartyId: thirdPartyId,
              kind: _accountKind,
              bankId: _accountKind == AccountKind.bank ? _bankId : null,
              accountType: _accountKind == AccountKind.bank ? _accountType : null,
              // Sin los espacios de la máscara: al back va el número, no cómo se lee.
              accountNumber: _accountKind == AccountKind.bank
                  ? InputMasks.digitsOnly(_accountNumber.text)
                  : null,
              brevKey: _accountKind == AccountKind.brev ? _brevKey.text : null,
              isPrimary: true,
            );
        ref.invalidate(myBankAccountsProvider);
      }
    } catch (_) {
      // Que falle guardar la cuenta no puede dejarlo atrapado en el alta: entra
      // igual y la registra luego desde su perfil. Se le dice, no se le esconde.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar tu cuenta. Agrégala luego desde tu perfil.'),
          ),
        );
      }
    }

    // La celebración se alcanza a ver antes de que el router nos saque.
    _mascot.celebrate();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    // TODO(back): enviar el resto de los datos capturados al servicio de empleados.
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
                              'PASO ${_step + 1} DE ${_lastStep + 1} · ${_eyebrows[_step]}',
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
                    children: List<Widget>.generate(_lastStep + 1, (i) {
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i < _lastStep ? AppSpacing.sm : 0),
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
                        _stepWrap(_bankStep()),
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
                                label: _step == _lastStep ? 'Empezar' : 'Continuar',
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
                textCapitalization: TextCapitalization.words,
                inputFormatters: InputMasks.personName(),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppTextField(
                label: 'Apellido',
                controller: _lastName,
                focusNode: _focuses[1],
                textCapitalization: TextCapitalization.words,
                inputFormatters: InputMasks.personName(),
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

  /// Dónde recibe la plata. Es el único paso del alta que se guarda de verdad:
  /// sin cuenta, el día de pago el dueño sólo puede darle efectivo.
  Widget _bankStep() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool esBrev = _accountKind == AccountKind.brev;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepHint(
          text: 'Aquí te consignamos tu nómina. Registra al menos una: podrás cambiarla o '
              'agregar más desde tu perfil.',
        ),
        const SizedBox(height: AppSpacing.xl),

        // Banco o BREV cambia todo lo demás, así que se elige primero.
        Row(
          children: [
            Expanded(child: _kindChip('Cuenta bancaria', AccountKind.bank, !esBrev)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _kindChip('Llave BREV', AccountKind.brev, esBrev)),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        if (esBrev) ...[
          AppTextField(
            label: 'Tu llave BREV',
            hint: 'Celular, correo o documento',
            controller: _brevKey,
            inputFormatters: InputMasks.brevKey(),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // Se avisa porque una llave "arreglada" manda la plata a otra parte.
            'Se guarda exactamente como la escribas. Revísala bien.',
            style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
          ),
        ] else ...[
          Text('Banco', style: AppTypography.labelMd(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _bankId,
            isExpanded: true,
            hint: const Text('Elige tu banco'),
            items: _banks
                .map((b) => DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),)
                .toList(),
            onChanged: (v) => setState(() => _bankId = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Tipo de cuenta', style: AppTypography.labelMd(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'SAVINGS', child: Text('Ahorros')),
              DropdownMenuItem(value: 'CHECKING', child: Text('Corriente')),
            ],
            onChanged: (v) => setState(() => _accountType = v ?? 'SAVINGS'),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Número de cuenta',
            hint: 'Sin puntos ni guiones',
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            inputFormatters: InputMasks.accountNumber(),
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }

  Widget _kindChip(String label, AccountKind kind, bool selected) {
    return InkWell(
      onTap: () => setState(() {
        _accountKind = kind;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryFixed : Colors.transparent,
          border: Border.all(
            color: selected ? AppColors.primary : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd(
            color: selected ? AppColors.onPrimaryFixed : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
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
