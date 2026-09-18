import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/finance/bank_account_repository.dart';
import 'package:saas_app/shared/util/input_masks.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';
import 'package:saas_app/shared/widgets/app_text_field.dart';

/// Mis cuentas: a dónde le consignan la nómina.
///
/// Es suya, no del negocio: si mañana trabaja en otra sede se las lleva. Por eso
/// la gestiona él y no su jefe — y por eso está aquí y no en una pantalla del
/// dueño.
///
/// La PRINCIPAL es la que el dueño ve primero el día de pago. Solo puede haber
/// una y eso lo garantiza la base de datos, así que aquí basta con pedirla.
class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<BankAccount>> cuentas = ref.watch(myBankAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _agregar(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: cuentas.when(
        loading: () => const AppLoader(),
        error: (_, __) => _Aviso(
          texto: 'No se pudieron cargar tus cuentas. Revisa tu conexión.',
          color: scheme.onSurfaceVariant,
        ),
        data: (lista) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.section * 2,
          ),
          children: [
            Text(
              'Aquí te consignan tu nómina. La cuenta principal es la que tu jefe '
              've primero el día de pago.',
              style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (lista.isEmpty)
              _Aviso(
                texto: 'Todavía no tienes ninguna cuenta. Agrega una para que puedan pagarte.',
                color: scheme.onSurfaceVariant,
              )
            else
              for (final BankAccount c in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _Cuenta(
                    cuenta: c,
                    // La principal no se puede borrar ni "volver a marcar":
                    // dejar a alguien sin cuenta de destino rompe su pago.
                    onPrincipal: c.isPrimary
                        ? null
                        : () async {
                            await ref.read(bankAccountRepositoryProvider).makePrimary(c.id);
                            ref.invalidate(myBankAccountsProvider);
                          },
                    onBorrar: c.isPrimary || lista.length == 1
                        ? null
                        : () async {
                            await ref.read(bankAccountRepositoryProvider).remove(c.id);
                            ref.invalidate(myBankAccountsProvider);
                          },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _agregar(BuildContext context, WidgetRef ref) async {
    final String? thirdPartyId = await ref.read(myThirdPartyIdProvider.future);
    if (thirdPartyId == null || !context.mounted) return;
    final bool? creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NuevaCuentaSheet(thirdPartyId: thirdPartyId),
    );
    if (creada == true) ref.invalidate(myBankAccountsProvider);
  }
}

class _Cuenta extends StatelessWidget {
  const _Cuenta({required this.cuenta, this.onPrincipal, this.onBorrar});
  final BankAccount cuenta;
  final Future<void> Function()? onPrincipal;
  final Future<void> Function()? onBorrar;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
        border: cuenta.isPrimary
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: cuenta.isPrimary ? AppColors.primaryFixed : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(
              cuenta.kind == AccountKind.brev
                  ? Icons.key_outlined
                  : Icons.account_balance_outlined,
              size: 20,
              color: cuenta.isPrimary ? AppColors.onPrimaryFixedVariant : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cuenta.label.isEmpty ? 'Cuenta' : cuenta.label,
                  maxLines: 2,
                  style: AppTypography.titleMd(color: scheme.onSurface),
                ),
                if (cuenta.isPrimary) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const AppTag(label: 'Principal', tone: AppTagTone.primary),
                ],
              ],
            ),
          ),
          if (onPrincipal != null || onBorrar != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
              onSelected: (v) async {
                if (v == 'principal') await onPrincipal?.call();
                if (v == 'borrar') await onBorrar?.call();
              },
              itemBuilder: (_) => [
                if (onPrincipal != null)
                  const PopupMenuItem(value: 'principal', child: Text('Hacer principal')),
                if (onBorrar != null)
                  const PopupMenuItem(value: 'borrar', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
    );
  }
}

/// Alta de cuenta. Dos formas, y cada una pide SOLO lo suyo: pedir el banco
/// para una llave BREV, o la llave para una cuenta de banco, es lo que hace que
/// la gente abandone el formulario.
class _NuevaCuentaSheet extends ConsumerStatefulWidget {
  const _NuevaCuentaSheet({required this.thirdPartyId});
  final String thirdPartyId;

  @override
  ConsumerState<_NuevaCuentaSheet> createState() => _NuevaCuentaSheetState();
}

class _NuevaCuentaSheetState extends ConsumerState<_NuevaCuentaSheet> {
  AccountKind _kind = AccountKind.bank;
  String? _bankId;
  String _accountType = 'SAVINGS';
  final TextEditingController _numero = TextEditingController();
  final TextEditingController _brev = TextEditingController();
  final TextEditingController _alias = TextEditingController();
  List<BankOption> _bancos = const [];
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Sin catálogo el desplegable sale vacío, pero la pantalla sigue en pie:
    // quedarse sin poder añadir una llave BREV porque no cargó la lista de
    // bancos sería castigar a quien ni siquiera la necesita.
    _cargarBancos();
  }

  Future<void> _cargarBancos() async {
    try {
      final List<BankOption> b = await ref.read(bankAccountRepositoryProvider).banks();
      if (mounted) setState(() => _bancos = b);
    } catch (_) {
      // Se queda con la lista vacía a propósito.
    }
  }

  @override
  void dispose() {
    _numero.dispose();
    _brev.dispose();
    _alias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nueva cuenta', style: AppTypography.headlineMd(color: scheme.onSurface)),
              const SizedBox(height: AppSpacing.lg),

              SegmentedButton<AccountKind>(
                segments: const [
                  ButtonSegment(value: AccountKind.bank, label: Text('Banco')),
                  ButtonSegment(value: AccountKind.brev, label: Text('Llave BREV')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_kind == AccountKind.bank) ...[
                DropdownButtonFormField<String>(
                  initialValue: _bankId,
                  decoration: const InputDecoration(labelText: 'Banco'),
                  items: [
                    for (final BankOption b in _bancos)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => _bankId = v),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _accountType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'SAVINGS', child: Text('Ahorros')),
                    DropdownMenuItem(value: 'CHECKING', child: Text('Corriente')),
                  ],
                  onChanged: (v) => setState(() => _accountType = v ?? 'SAVINGS'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _numero,
                  label: 'Número de cuenta',
                  hint: 'Sin puntos ni guiones',
                  keyboardType: TextInputType.number,
                  inputFormatters: InputMasks.accountNumber(),
                ),
              ] else ...[
                AppTextField(
                  controller: _brev,
                  label: 'Llave BREV',
                  hint: 'Tu celular, correo o documento',
                  inputFormatters: InputMasks.brevKey(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Se guarda tal cual la escribas: es lo que el banco resuelve.',
                  style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _alias,
                label: 'Nombre para reconocerla (opcional)',
                hint: 'La de la nómina, Mi Nequi…',
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: InputMasks.shortText(),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: AppTypography.bodySm(color: scheme.error)),
              ],

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
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardar() async {
    final bool banco = _kind == AccountKind.bank;
    if (banco && (_bankId == null || _numero.text.trim().isEmpty)) {
      setState(() => _error = 'Elige el banco y escribe el número.');
      return;
    }
    if (!banco && _brev.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu llave BREV.');
      return;
    }

    setState(() { _guardando = true; _error = null; });
    try {
      await ref.read(bankAccountRepositoryProvider).create(
            thirdPartyId: widget.thirdPartyId,
            kind: _kind,
            bankId: banco ? _bankId : null,
            accountType: banco ? _accountType : null,
            // Sin los espacios de la máscara: al back va el número, no cómo se lee.
            accountNumber: banco ? InputMasks.digitsOnly(_numero.text) : null,
            brevKey: banco ? null : _brev.text,
            alias: _alias.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar. Revisa los datos y tu conexión.';
      });
    }
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto, required this.color});
  final String texto;
  final Color color;

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
      child: Text(texto, textAlign: TextAlign.center, style: AppTypography.bodyMd(color: color)),
    );
  }
}
