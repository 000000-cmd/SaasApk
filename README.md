# SaaS App (móvil)

App Flutter del SaaS de gestión de locales (barberías/salones/spas).

## Acceso (importante)
- **Solo dueño (OWNER) y empleados (EMPLOYEE).**
- **El administrador del sistema (SYSTEM_ADMIN/ADMIN) NO entra al APK** — su acceso es la app web. Es el inverso de la web (web = dueño + admin del sistema).
- El gate de rol vive en [`lib/core/auth/auth_guard.dart`](lib/core/auth/auth_guard.dart). `EMPLOYEE` es un rol pendiente en el back (hoy existe `OWNER`); el gate ya lo contempla.

## Estado del proyecto
Ya inicializado: plataformas **android** + **web** generadas, deps resueltas, `flutter analyze` sin issues y tests en verde. Compila (`flutter build web` OK).

```bash
flutter run -d chrome   # probar en navegador ya mismo
flutter test            # corre los tests
```

### Para generar el APK (paso pendiente)
Falta el **Android SDK** (no instalado). Instala Android Studio (o `cmdline-tools`), acepta licencias y:

```bash
flutter doctor --android-licenses
flutter build apk        # genera el APK release
flutter run -d <device>  # corre en dispositivo/emulador Android
```

## Publicar una nueva versión (proceso de release)
1. Subir `version` en `pubspec.yaml` (x.y.z+code) y en `lib/core/config/app_info.dart`.
2. `flutter build apk --release` **firmado SIEMPRE con la misma keystore** — si cambia la firma, Android no actualiza en sitio y el usuario perdería su data al reinstalar.
3. En la web admin → *Versiones del APK* → subir el `.apk` con su versión y un `versionCode` **mayor** al vigente, y publicar.
4. Los teléfonos con versión distinta quedan bloqueados en la pantalla de actualización, que **descarga, verifica el checksum e instala** en sitio (la data local se conserva). El link estable de descarga (`/system/public/app-versions/latest/download`) es el que comparten los dueños.

## Login y primer ingreso del empleado
- **Login único** para dueño y empleado (mismo formulario). **No hay auto-registro de empleados**: sus cuentas las crea el **dueño** desde el dashboard (web). El registro de dueño vive en la web.
- **Primer ingreso del empleado**: al entrar por primera vez, el router lo lleva a `/employee-onboarding` para completar datos básicos antes de operar. El flag "onboarding hecho" se guarda por usuario en almacenamiento seguro; migrará a un campo del back (ver `TODO(back)` en `auth_controller.dart` y `employee_onboarding_screen.dart`).

## Arquitectura / estándar
Limpia y por features, espejando el front web (un propósito por archivo).

```
lib/
  app/            App raíz, router (guards), tema
    theme/        Tokens (colores, espaciado) + ThemeData light/dark
  core/           Infra transversal
    config/       env (base URL del gateway, prefijos de microservicios)
    network/      Dio + interceptores (JWT, refresh, error) + ApiResponse<T>
    storage/      Token storage seguro
    auth/         modelos, repositorio, controller (Riverpod), role gate
  shared/
    widgets/      Design system (AppButton, AppTextField, AppCard, AppTag, AppScaffold…)
  features/
    splash/  auth/  home/  …   Una carpeta por feature; pantalla + lógica propias
```

### Convenciones
1. **Estado**: Riverpod (`Notifier`/`AsyncNotifier`). Nada de `setState` para estado de dominio.
2. **Red**: todo pasa por `ApiClient` (Dio). El back responde el envelope `ApiResponse<T>` (`{ success, data, message }`); usar `ApiResponse.data`.
3. **Auth**: tokens en `flutter_secure_storage`. El interceptor agrega `Authorization: Bearer` y hace refresh transparente (igual que el front web).
4. **Diseño**: usar SIEMPRE los componentes de `shared/widgets` y los tokens de `app/theme` (no widgets Material crudos sueltos ni colores hardcodeados). Branding terracota/crema = mismo del web.
5. **IDs vs códigos**: comparar por Id; para condicionales sobre listas/constantes (catálogos, constantes como `MAYEDAD`) usar el **código** y su valor, igual que en back/web.
6. **Idioma**: UI en español; código/identificadores en inglés.

## Backend
Consume el mismo gateway que la web (`config/env.dart`). Microservicios: `auth`, `system`, `business`, `thirdparty`, `search`, `audit`.
