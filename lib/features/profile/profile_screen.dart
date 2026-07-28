import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/auth/auth_models.dart';
import 'package:saas_app/core/config/app_info.dart';
import 'package:saas_app/core/finance/balance_repository.dart';
import 'package:saas_app/core/theme/theme_controller.dart';
import 'package:saas_app/shared/util/money.dart';
import 'package:saas_app/shared/widgets/app_button.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';

/// Perfil: identidad del usuario + preferencias del dispositivo (huella) +
/// cierre de sesión. El avatar lleva el anillo degradado de la marca.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _bioSupported = false;
  bool _bioEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final bool supported = await ref.read(biometricServiceProvider).isSupported();
    final bool enabled =
        await ref.read(authControllerProvider.notifier).isBiometricEnabledForCurrentUser();
    if (mounted) {
      setState(() {
        _bioSupported = supported;
        _bioEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    final AuthController controller = ref.read(authControllerProvider.notifier);
    if (value) {
      final bool ok = await controller.enableBiometrics();
      if (mounted) setState(() => _bioEnabled = ok);
    } else {
      await controller.disableBiometrics();
      if (mounted) setState(() => _bioEnabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(authControllerProvider).user;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String initials = (user?.fullName ?? user?.username ?? '?')
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    final bool isOwner = user?.kind == UserKind.owner;
    final EmployeeBalance balance = ref.watch(myBalanceProvider).valueOrNull ?? EmployeeBalance.zero;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
        ),
        children: [
          // ---- Identidad ----
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryContainer, AppColors.primaryFixedDim],
                ),
                boxShadow: AppElevation.glow,
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: scheme.surfaceContainerLowest,
                child: Text(
                  initials,
                  style: AppTypography.headlineMd(color: AppColors.onPrimaryFixedVariant),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            user?.fullName ?? user?.username ?? '',
            textAlign: TextAlign.center,
            style: AppTypography.headlineMd(color: scheme.onSurface),
          ),
          if (user?.email != null) ...[
            const SizedBox(height: 2),
            Text(
              user!.email!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Center(
            child: AppTag(
              label: isOwner ? 'Dueño del negocio' : 'Miembro del equipo',
              tone: AppTagTone.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          // ---- Rendimiento (solo empleado: son SUS cifras) ----
          if (!isOwner) ...[
            Text('Tu rendimiento', style: AppTypography.headlineMd(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _StatTile(label: 'Devengado', value: formatCOP(balance.accrued)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _StatTile(label: 'Cobrado', value: formatCOP(balance.paid)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _StatTile(
              label: 'Por cobrar',
              value: formatCOP(balance.balance),
              highlight: true,
            ),
            const SizedBox(height: AppSpacing.md),
            const _StatTile(
              label: 'Servicios realizados',
              value: '—',
              pending: true,
              hint: 'Llega con el módulo de citas',
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],

          // ---- Cuenta ----
          Text('Cuenta', style: AppTypography.headlineMd(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.md),
          if (_bioSupported)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                boxShadow: AppElevation.card,
              ),
              child: Row(
                children: [
                  Icon(Icons.fingerprint, color: scheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Entrar con huella',
                      style: AppTypography.bodyMd(color: scheme.onSurface),
                    ),
                  ),
                  Switch(
                    value: _bioEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: _toggleBiometrics,
                  ),
                ],
              ),
            ),
          // Modo oscuro (por defecto claro; la preferencia se guarda).
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              boxShadow: AppElevation.card,
            ),
            child: Row(
              children: [
                Icon(
                  ref.watch(themeModeProvider) == ThemeMode.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Modo oscuro',
                    style: AppTypography.bodyMd(color: scheme.onSurface),
                  ),
                ),
                Switch(
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => ref.read(themeModeProvider.notifier).setDark(v),
                ),
              ],
            ),
          ),
          AppButton(
            label: 'Cerrar sesión',
            variant: AppButtonVariant.secondary,
            icon: Icons.logout_rounded,
            expanded: true,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Versión ${AppInfo.version}',
            textAlign: TextAlign.center,
            style: AppTypography.labelSm(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}

/// Recuadro de rendimiento. `pending` marca lo que llega con citas.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.highlight = false,
    this.pending = false,
    this.hint,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool pending;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryFixed.withValues(alpha: 0.45) : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: highlight ? null : AppElevation.card,
        border: highlight
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.15))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTypography.labelSm(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.headlineMd(
                color: pending
                    ? scheme.outline
                    : (highlight ? AppColors.onPrimaryFixedVariant : scheme.onSurface),
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: AppTypography.labelSm(color: scheme.outline)),
          ],
        ],
      ),
    );
  }
}
