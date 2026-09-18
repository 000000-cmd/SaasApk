package com.saas.app.saas_app

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (no FlutterActivity): requisito de local_auth para
// mostrar el prompt biometrico del sistema.
class MainActivity : FlutterFragmentActivity() {

    /**
     * Identidad del APARATO, para la vinculacion de sesion.
     *
     * Se resuelve en Kotlin y no en Dart porque el unico identificador que
     * cumple lo que hace falta —sobrevivir a que se desinstale la app, se
     * borren sus datos o se limpie la cache— es ANDROID_ID, y solo se puede
     * leer desde el lado nativo.
     *
     * Que es exactamente: un valor de 64 bits que Android genera por
     * combinacion de usuario del telefono y clave de firma de la app. Eso
     * significa dos cosas buenas:
     *   - Reinstalar el MISMO APK firmado igual devuelve el MISMO valor.
     *   - Otra app del telefono NO puede leer el nuestro, porque su clave de
     *     firma es otra. No es un identificador rastreable entre aplicaciones.
     * Se reinicia solo al restaurar el telefono de fabrica, que es justamente
     * cuando tiene sentido considerarlo otro aparato.
     *
     * No requiere ningun permiso.
     */
    private val CANAL = "moda_erp/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceId" -> result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                    // "Samsung Galaxy A54" — para que el aviso de sesion abierta
                    // diga de que telefono se trata y no "otro dispositivo".
                    "deviceName" -> result.success(nombreLegible())
                    else -> result.notImplemented()
                }
            }
    }

    private fun nombreLegible(): String {
        val marca = Build.MANUFACTURER ?: ""
        val modelo = Build.MODEL ?: ""
        // Muchos fabricantes ya meten la marca dentro del modelo ("Pixel 8" no,
        // pero "Xiaomi Redmi Note" si). Repetirla se lee mal.
        val nombre = if (modelo.startsWith(marca, ignoreCase = true)) modelo
                     else "$marca $modelo".trim()
        return nombre.ifBlank { "Android" }
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
    }
}
