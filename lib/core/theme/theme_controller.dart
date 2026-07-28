import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Modo de tema de la app. Arranca en CLARO (no en el del sistema) y el usuario
/// puede pasar a oscuro con el interruptor del perfil. La preferencia se guarda
/// y sobrevive a reinicios.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light; // default: claro
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'dark') {
      state = ThemeMode.dark;
    } else if (saved == 'light') {
      state = ThemeMode.light;
    }
    // Sin valor guardado: se queda en el default (claro).
  }

  Future<void> setDark(bool dark) async {
    state = dark ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(key: _key, value: dark ? 'dark' : 'light');
  }

  Future<void> toggle() => setDark(state != ThemeMode.dark);
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
