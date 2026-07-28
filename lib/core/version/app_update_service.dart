import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saas_app/core/auth/auth_controller.dart';
import 'package:saas_app/core/network/api_client.dart';
import 'package:saas_app/core/version/version_gate.dart';

final appUpdateServiceProvider =
    Provider<AppUpdateService>((ref) => AppUpdateService(ref.watch(apiClientProvider)));

/// Auto-actualización del APK: descarga la versión vigente, verifica su
/// integridad (SHA-256 contra la metadata publicada) y lanza el instalador
/// del sistema. Android actualiza EN SITIO (misma firma + versionCode mayor),
/// por lo que la data local del usuario se conserva.
class AppUpdateService {
  AppUpdateService(this._client);
  final ApiClient _client;

  /// Descarga el APK a almacenamiento temporal reportando progreso 0..1.
  Future<File> download(LatestApp latest, void Function(double progress) onProgress) async {
    final Directory dir = await getTemporaryDirectory();
    final File file = File('${dir.path}/saas-app-${latest.version}.apk');
    await _client.dio.download(
      latest.downloadPath.replaceFirst(RegExp(r'^/'), ''),
      file.path,
      onReceiveProgress: (int received, int total) {
        final int expected = total > 0 ? total : (latest.sizeBytes ?? 0);
        if (expected > 0) onProgress(received / expected);
      },
    );
    return file;
  }

  /// Verifica el SHA-256 del archivo descargado contra el publicado.
  Future<bool> verify(File file, String expectedChecksum) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expectedChecksum.toLowerCase();
  }

  /// Abre el instalador del sistema con el APK (REQUEST_INSTALL_PACKAGES).
  Future<bool> install(File file) async {
    final OpenResult result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    return result.type == ResultType.done;
  }
}
