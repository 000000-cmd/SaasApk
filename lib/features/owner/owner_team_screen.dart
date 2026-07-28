import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_elevation.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/business/team_repository.dart';
import 'package:saas_app/shared/widgets/app_loader.dart';
import 'package:saas_app/shared/widgets/app_tag.dart';

/// "Supervisión de Equipo" del dueño: quién está en la nómina y en qué sede.
///
/// El ESTADO en vivo (en servicio / disponible / en descanso) depende del
/// módulo de citas; hasta entonces se muestra lo que sí es real: si el
/// colaborador ya completó su perfil desde el APK o sigue como alta mínima.
class OwnerTeamScreen extends ConsumerWidget {
  const OwnerTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AsyncValue<List<TeamMember>> team = ref.watch(teamProvider);
    final AsyncValue<List<Branch>> branches = ref.watch(branchesProvider);

    return SafeArea(
      bottom: false,
      child: team.when(
        loading: () => const AppLoader(),
        error: (_, __) => const Center(child: Text('No se pudo cargar el equipo')),
        data: (members) {
          final int pending = members.where((m) => m.isPending).length;
          final int active = members.length - pending;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(branchesProvider);
              await ref.read(teamProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.marginMobile, AppSpacing.lg, AppSpacing.marginMobile, AppSpacing.bottomForNavBar(context),
              ),
              children: [
                Text('Estado del equipo', style: AppTypography.headlineLg(color: scheme.onSurface)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  branches.valueOrNull == null || branches.valueOrNull!.isEmpty
                      ? 'Sin sedes registradas'
                      : '${branches.valueOrNull!.length} sede(s)',
                  style: AppTypography.bodyMd(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ---- Resumen ----
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Con perfil',
                        value: '$active',
                        total: members.length,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _StatCard(
                        label: 'Por completar',
                        value: '$pending',
                        muted: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                if (members.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                      boxShadow: AppElevation.card,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Aún no tienes equipo',
                          style: AppTypography.titleMd(color: scheme.onSurface),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Da de alta a tus colaboradores desde la plataforma web.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  ...members.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _MemberCard(member: m),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.total, this.muted = false});
  final String label;
  final String value;
  final int? total;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.labelSm(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: AppTypography.displayXl(
                      color: muted ? scheme.onSurfaceVariant : scheme.primary,
                    ),
                  ),
                ),
              ),
              if (total != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
                  child: Text(
                    '/ $total',
                    style: AppTypography.labelMd(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppElevation.card,
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: member.photoUrl == null || member.photoUrl!.isEmpty
                ? const Icon(Icons.person_outline, color: AppColors.onPrimaryFixedVariant, size: 22)
                : Image.network(
                    member.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person_outline, color: AppColors.onPrimaryFixedVariant, size: 22),
                  ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMd(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  member.branchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppTag(
                  label: member.isPending ? 'Perfil pendiente' : 'Activo',
                  tone: member.isPending ? AppTagTone.neutral : AppTagTone.success,
                  dot: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
