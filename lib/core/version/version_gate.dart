import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/config/app_info.dart';

/// Versión vigente publicada por el administrador (contrato público
/// /system/public/app-versions/latest). Incluye lo necesario para descargar,
/// verificar e instalar la actualización desde el propio APK.
class LatestApp {
  final String version;
  final int? versionCode;
  final String? notes;
  final String checksum;
  final int? sizeBytes;

  /// Ruta RELATIVA al gateway (el cliente la prefija con su base conocida).
  final String downloadPath;

  const LatestApp({
    required this.version,
    this.versionCode,
    this.notes,
    required this.checksum,
    this.sizeBytes,
    required this.downloadPath,
  });

  factory LatestApp.fromJson(Map<String, dynamic> j) => LatestApp(
        version: (j['version'] ?? '').toString(),
        versionCode: (j['versionCode'] as num?)?.toInt(),
        notes: j['notes'] as String?,
        checksum: (j['checksum'] ?? '').toString(),
        sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
        downloadPath: (j['downloadPath'] ?? '').toString(),
      );
}

class VersionState {
  /// La instalada difiere de la vigente: bloquear hasta actualizar.
  final bool updateRequired;
  final LatestApp? latest;

  const VersionState({this.updateRequired = false, this.latest});
}

final versionGateProvider = NotifierProvider<VersionGate, VersionState>(VersionGate.new);

/// Compara [AppInfo.version] contra la vigente al ARRANCAR (endpoint público,
/// sin sesión): un APK desactualizado se bloquea incluso antes del login.
/// Ante fallo de red no bloquea (fail-open): la conectividad no puede dejar
/// al usuario por fuera.
class VersionGate extends Notifier<VersionState> {
  @override
  VersionState build() {
    Future.microtask(_check);
    return const VersionState();
  }

  Future<void> recheck() => _check();

  Future<void> _check() async {
    try {
      final Response<dynamic> res = await ref
          .read(apiClientProvider)
          .dio
          .get<dynamic>('system/public/app-versions/latest');
      final Map<String, dynamic>? data =
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>?;
      if (data == null) {
        state = const VersionState(); // sin version publicada: no exigir nada
        return;
      }
      final LatestApp latest = LatestApp.fromJson(data);
      state = VersionState(
        updateRequired: latest.version != AppInfo.version,
        latest: latest,
      );
    } catch (_) {
      state = const VersionState(); // fail-open
    }
  }
}
