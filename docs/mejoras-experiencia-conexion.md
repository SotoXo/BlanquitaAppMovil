# Transiciones y experiencia de conexión

Fecha: 20 de octubre de 2026. Rama de trabajo: `feat/victor-hamburger-ui`.
Referencia de integración: commit de Soto `430aef7` en `origin/feat/furuxqfurula` (finales de carrera y conexión de visión), junto con los cambios locales que ya estaban presentes.

## Comportamiento visible

- Las secciones cambian directamente con un fundido de 260 ms, sin recorrer pantallas intermedias. Las pulsaciones sucesivas conservan el último destino.
- ALFRESI muestra «Pensando…» con tres puntos durante operaciones pendientes. La animación respeta movimiento reducido, modo rendimiento y la preferencia de animaciones del asistente.
- Las comprobaciones de Ajustes escuchan al controlador correspondiente: búsqueda, conexión, identidad/autorización del ESP32 o confirmación del servicio de visión. No presentan porcentajes inventados.
- Después de ocho segundos aparece una explicación de la demora y cómo revisar la red. Este aviso no declara un fallo ni modifica los tiempos del protocolo.
- Cancelar muestra «Cancelando…» mientras se cierra el intento. Una respuesta tardía no abre un mensaje de éxito. Si el cierre falla, se ofrece una salida y se registra el incidente.
- Se mantienen las acciones de reintentar y abrir Diagnósticos. Los errores inesperados de comprobación se registran sin mostrar excepciones crudas al usuario.
- El asistente diferencia lecturas de seguridad pendientes, límites contradictorios y preparación de visión. Las pantallas inactivas de visión y vinculación no simulan una operación en curso.
- Dispositivos explica el enlace que está buscando o conectando y permite cancelar también la búsqueda de visión.
- La vinculación utiliza el mismo diálogo de progreso, cancelación y recuperación. Su confirmación espera el almacenamiento seguro de la credencial; cancelar descarta un resultado tardío.
- Visión ofrece reintento y diagnóstico visibles al fallar. El estado de espera sigue disponible al desactivar ALFRESI.
- Los formularios de identidad y clave permiten desplazamiento con teclado o texto grande.
- Una secuencia solicitada muestra «Esperando confirmación» hasta que el ESP32 informa su ejecución.
- Las comprobaciones empiezan después de dibujar el diálogo para admitir controladores que notifican cambios inmediatamente.

## Alcance

Los cambios usan los controladores existentes. El acceso de control sigue dependiendo del protocolo ESP32 y las lecturas de seguridad; la visión conserva su conexión independiente. No se modificaron firmware, credenciales ni reglas de movimiento.

## Verificación reproducible

Resultado final de esta sesión: `flutter analyze` sin incidencias, `flutter test` con 244 pruebas aprobadas y `flutter build apk --debug` completado. APK generado: `build/app/outputs/flutter-apk/app-debug.apk`.

```powershell
flutter analyze
flutter test
flutter test test/connection_feedback_ux_test.dart --dart-define=CAPTURAR_UX_CONEXION=true
flutter build apk --debug
```

Las pruebas nuevas cubren fases en vivo, espera prolongada, cancelación y respuesta tardía, fallo de cierre, excepción al conectar, reintento, movimiento reducido y modo horizontal con texto al 200 % en temas claro y oscuro. También comprueban vinculación con almacenamiento demorado, fallo de almacenamiento, cancelación durante el guardado y recuperación de visión con el asistente desactivado. Se ajustaron las pruebas visuales antiguas para responder al protocolo completo de visión y comprobar el bloqueo manual que utiliza la integración actual.

Las capturas de `docs/evidencias/ux-conexion/` proceden de widgets Flutter con respuestas controladas para la prueba. No constituyen evidencia de conexión física. En esta sesión no se detectó un teléfono Android conectado; quedan pendientes la instalación y la comprobación con ESP32 y laptop reales.
