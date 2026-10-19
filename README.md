# sharedpref

A new Flutter project.

## Configuración de Firebase (Android)

La aplicación usa Firebase Authentication para iniciar sesión, crear cuentas y
enviar correos de recuperación de contraseña. Antes de ejecutarla:

1. Crea un proyecto en Firebase y registra una aplicación Android con el ID
   `com.example.sharedpref`.
2. Descarga el archivo `google-services.json` y colócalo en
   `android/app/google-services.json`.
3. En Firebase Console, activa el proveedor **Correo electrónico/Contraseña**
   en **Authentication > Sign-in method**.
4. Revisa y personaliza la plantilla de restablecimiento de contraseña en
   **Authentication > Templates**.
5. Ejecuta `flutter run`.

La configuración de Firebase es específica del proyecto y no se incluye en
este repositorio. Si cambias el `applicationId` de Android, registra ese ID
también en Firebase y descarga de nuevo el archivo de configuración.

## Diagnóstico de recuperación de contraseña

- Confirma que el proveedor **Correo electrónico/Contraseña** esté habilitado
  en **Authentication > Sign-in method** y que la plantilla de restablecimiento
  esté activa en **Authentication > Templates**.
- Usa una dirección con cuenta registrada para comprobar la entrega. Firebase
  puede responder de forma genérica para direcciones no registradas cuando está
  habilitada la protección contra enumeración de correos.
- Verifica que `android/app/google-services.json` pertenezca al mismo proyecto
  Firebase y contenga una aplicación Android cuyo paquete sea
  `com.example.sharedpref` (el `applicationId` actual).
- El mensaje de la app confirma que Firebase aceptó la solicitud; no confirma
  que el proveedor de correo la haya entregado en la bandeja de entrada.
  Comprueba Spam/No deseado, filtros, bloqueos del remitente y posibles
  retrasos. En Firebase Console revisa la configuración de la plantilla y el
  uso/límites de Authentication; no se debe tratar la respuesta del SDK como
  comprobante de entrega.
