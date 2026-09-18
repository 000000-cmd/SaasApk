import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saas_app/core/config/app_info.dart';
import 'package:saas_app/core/storage/token_storage.dart';

/// Quién es ESTE aparato.
///
/// Es la mitad del par que guarda `usuarios_vinculaciones` (la otra es la
/// cuenta). Lo que se necesita de este identificador es una sola cosa: que sea
/// el mismo mañana. Si cambiara al desinstalar la app, cada reinstalación
/// parecería un teléfono nuevo, saltaría el aviso de "tu cuenta está abierta en
/// otro dispositivo" y la regla se volvería un estorbo.
///
/// Por eso se pide a Android su `ANDROID_ID` a través de un canal nativo, y no
/// se genera aquí: un valor generado en Dart sólo puede vivir en el
/// almacenamiento de la app, y el almacenamiento de la app se va con ella.
///
/// El respaldo generado existe para lo que Android no cubre (el emulador
/// devuelve nulo en algunos casos, y en escritorio no hay canal). Se guarda en
/// el llavero seguro y se marca como tal: sirve para operar, pero no promete la
/// misma permanencia.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  static const MethodChannel _canal = MethodChannel('moda_erp/device');

  final TokenStorage _storage;

  String? _cacheId;
  String? _cacheNombre;

  /// Identificador estable del aparato. Nunca lanza: si todo falla, devuelve el
  /// respaldo. Un login no se puede caer porque no se supo el modelo del móvil.
  Future<String> id() async {
    if (_cacheId != null) return _cacheId!;

    String? nativo;
    try {
      nativo = await _canal.invokeMethod<String>('deviceId');
    } on PlatformException catch (_) {
      nativo = null;
    } on MissingPluginException catch (_) {
      // Plataforma sin canal (escritorio, tests): se usa el respaldo.
      nativo = null;
    }

    if (nativo != null && nativo.trim().isNotEmpty && nativo != 'null') {
      _cacheId = nativo.trim();
      return _cacheId!;
    }
    _cacheId = await _respaldo();
    return _cacheId!;
  }

  /// Cómo llamarlo al preguntarle a la persona: "Samsung Galaxy A54".
  Future<String> name() async {
    if (_cacheNombre != null) return _cacheNombre!;
    try {
      _cacheNombre = await _canal.invokeMethod<String>('deviceName') ?? 'Este dispositivo';
    } catch (_) {
      _cacheNombre = 'Este dispositivo';
    }
    return _cacheNombre!;
  }

  /// Lo que viaja en el login.
  Future<Map<String, String>> payload() async => <String, String>{
        'deviceId': await id(),
        'deviceName': await name(),
        'platform': 'ANDROID',
        'appVersion': AppInfo.version,
      };

  /// Identificador propio, guardado en el llavero. Se genera UNA vez.
  Future<String> _respaldo() async {
    final String? guardado = await _storage.deviceFallbackId();
    if (guardado != null && guardado.isNotEmpty) return guardado;

    // Aleatorio de 128 bits en hexadecimal. No hace falta un UUID con formato:
    // esto no se compara con nada de fuera, sólo consigo mismo.
    final Random r = Random.secure();
    final String nuevo = List<String>.generate(
      32,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    await _storage.setDeviceFallbackId(nuevo);
    return nuevo;
  }
}

final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(const TokenStorage()),
);
