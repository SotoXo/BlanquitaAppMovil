# Hotfix: edición de URLs, autoconexión y lifecycle

## Causa reproducida

Antes de corregir el código, los dos tests de guardar URL fallaban:

- ESP32: `A TextEditingController was used after being disposed.` El controlador
  se disponía al completar `showDialog`, mientras su ruta todavía se cerraba.
- Vision: `framework.dart: '_dependents.isEmpty': is not true`, al construir
  `_FocusInheritedScope`. La espera fija de 250 ms no garantizaba la retirada
  del overlay. Además, `Consumer<SettingsController>` reconstruía `MaterialApp`
  por cambios de URL durante ese cierre.

La reproducción se ejecutó con widget tests sobre la implementación anterior;
no se necesitó modificar el framework ni el protocolo de los dispositivos.

## Cambios

`app.dart` selecciona únicamente `ThemeMode` con
`Selector<SettingsController, ThemeMode>`. El `MainShell` es su child estable.
Las URLs, timeouts, confianza y reconexión se observan en sus pantallas, sin
reconstruir `MaterialApp` ni reemplazar Navigator, shell o providers globales.
Cambiar el tema sigue funcionando y conserva sus estados.

Los dos editores usan `_showUrlDialog`: espera `showDialog`, después
`TransitionRoute.completed` (animación finalizada y entradas del overlay
retiradas), comprueba `mounted` y dispone el controlador de texto. Solo entonces
se guarda y se conecta. No hay esperas arbitrarias ni uso de context después
de desmontar la pantalla. Los controladores invalidan conexiones anteriores al
editar y comprueban la generación tras persistir; una desconexión manual durante
esa espera evita la reconexión. Vision suprime su listener de reconexión mientras
guarda, para iniciar un único intento después de persistir.

## Inicio y recuperación

El inicio lanza `MachineController.connect()` y `VisionController.connect()`
independientemente, también cuando ambas URLs están vacías. Si el arranque
queda inactivo antes del intento inicial, este se difiere hasta `resumed`.

Cada controlador prueba primero su URL guardada. Si falta o falla el handshake,
busca por UDP (ESP32 4210, Vision 4211), construye el candidato desde la IP del
remitente y abre su WebSocket (81 y 8765 respectivamente). Solo `READY` o un
`vision.ready` válido permiten guardar el candidato. Un fallo conserva la URL
manual; las reconexiones mantienen sus backoffs existentes, sin escaneos.

En `inactive`, ESP32 envía el STOP existente para movimiento manual, detiene
el heartbeat y ambos controladores suspenden sockets, discovery e intentos
pendientes, invalidando sus generaciones. Así un socket TCP que pareciera
seguir conectado a la red anterior no bloquea la recuperación. Al volver,
si la reconexión está habilitada y el usuario no desconectó manualmente,
se repite URL conocida → discovery → handshake → persistencia. No se presumen
rangos IP: sirve para 192.168.137.x, 10.42.x.x, 172.20.x.x y otras redes IPv4.

Los comandos físicos, heartbeat ESP32 de 200 ms y JSON Vision siguen iguales.
El contrato del servidor Python externo permanece en
[vision-discovery.md](vision-discovery.md); este hotfix no modifica Python.

## Pruebas

`test/hotfix_connection_widget_test.dart` verifica guardar ESP32 y Vision sin
errores Flutter (incluido `_dependents.isEmpty`), sin persistir durante el cierre
y manteniendo las identidades de MaterialApp, Navigator, MainShell y providers.
También comprueba el tema, URLs vacías, URLs obsoletas, arranque inactivo,
recuperación DHCP en tres redes, búsquedas simultáneas, Vision fallando con
control manual ESP32 operativo, cancelación al guardar y respuestas obsoletas
posteriores a un nuevo discovery. El test de seguridad ESP32 comprueba STOP,
heartbeat de 200 ms, nuevo READY al volver y final de carrera.

Comandos de validación:

```text
flutter test test/hotfix_connection_widget_test.dart --plain-name "guardar URL"
flutter analyze
flutter test
flutter build apk --debug
```

Resultado: los dos tests específicos de guardar URL pasan; los 11 widget tests
del hotfix pasan; la suite completa pasa sus 89 tests; `flutter analyze` no
encuentra problemas y el APK debug se compila correctamente. No se realizó
commit ni push.

Archivos de este hotfix (además de los cambios de discovery que ya estaban en
el workspace):

- `lib/app/app.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/core/websocket/machine_controller.dart`
- `lib/features/vision/controller/vision_controller.dart`
- `test/hotfix_connection_widget_test.dart`
- `test/core/websocket/machine_controller_test.dart`
- `README.md`
- `docs/connection-hotfix.md`
