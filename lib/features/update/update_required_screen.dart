import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/app/theme/app_colors.dart';
import 'package:saas_app/app/theme/app_spacing.dart';
import 'package:saas_app/app/theme/app_typography.dart';
import 'package:saas_app/core/config/app_info.dart';
import 'package:saas_app/core/version/app_update_service.dart';
import 'package:saas_app/core/version/version_gate.dart';
import 'package:saas_app/shared/widgets/app_button.dart';

enum _Phase { idle, downloading, verifying, ready, error }

/// Bloqueo por versión: descarga la vigente, verifica el checksum y lanza el
/// instalador — el usuario actualiza sin salir de la app. La instalación es
/// en sitio (misma firma, versionCode mayor), así que su data se conserva.
class UpdateRequiredScreen extends ConsumerStatefulWidget {
  const UpdateRequiredScreen({super.key});

  @override
  ConsumerState<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends ConsumerState<UpdateRequiredScreen> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;
  File? _apk;

  Future<void> _downloadAndInstall() async {
    final LatestApp? latest = ref.read(versionGateProvider).latest;
    if (latest == null) return;
    final AppUpdateService updater = ref.read(appUpdateServiceProvider);

    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final File file = _apk ??
          await updater.download(latest, (p) {
            if (mounted) setState(() => _progress = p.clamp(0, 1));
          });

      setState(() => _phase = _Phase.verifying);
      final bool ok = await updater.verify(file, latest.checksum);
      if (!ok) {
        await file.delete();
        _apk = null;
        setState(() {
          _phase = _Phase.error;
          _error = 'El archivo descargado no pasó la verificación. Intenta de nuevo.';
        });
        return;
      }

      _apk = file;
      setState(() => _phase = _Phase.ready);
      final bool launched = await updater.install(file);
      if (!launched && mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'No se pudo abrir el instalador. Permite "instalar apps desconocidas" para esta app e intenta de nuevo.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'No se pudo descargar la actualización. Revisa tu conexión.';
        });
      }
    }
  }

  String _buttonLabel() => switch (_phase) {
        _Phase.downloading => 'Descargando… ${(_progress * 100).toStringAsFixed(0)}%',
        _Phase.verifying => 'Verificando…',
        _Phase.ready => 'Instalar de nuevo',
        _Phase.error => 'Reintentar',
        _Phase.idle => 'Descargar e instalar',
      };

  @override
  Widget build(BuildContext context) {
    final VersionState version = ref.watch(versionGateProvider);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool busy = _phase == _Phase.downloading || _phase == _Phase.verifying;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                  child: const Icon(Icons.system_update_alt, size: 34, color: AppColors.onPrimaryFixedVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Hay una nueva versión',
                textAlign: TextAlign.center,
                style: AppTypography.headlineMd(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                version.latest == null
                    ? 'Debes actualizar la app para continuar.'
                    : 'Actualiza a la versión ${version.latest!.version} para continuar. '
                        'Tus datos se conservan: es una actualización en sitio.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMd(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              if (version.latest?.notes != null && version.latest!.notes!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Text(
                    version.latest!.notes!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySm(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (busy) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: _phase == _Phase.downloading ? _progress : null,
                    minHeight: 6,
                    backgroundColor: dark ? AppColors.surfaceContainerDark : AppColors.surfaceContainer,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center, style: AppTypography.bodySm(color: AppColors.error)),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: _buttonLabel(),
                icon: busy ? null : Icons.download,
                loading: _phase == _Phase.verifying,
                expanded: true,
                onPressed: busy || version.latest == null ? null : _downloadAndInstall,
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Versión instalada ${AppInfo.version}',
                  style: AppTypography.labelSm(color: AppColors.outline),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
