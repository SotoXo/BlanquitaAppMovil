# Mobile ↔ BLANQUITA Vision: diagnóstico y corrección

Fecha: 18 de octubre de 2026. Alcance: exclusivamente Mobile.

## Causa raíz confirmada en el código

`VisionDiscoveryService.parseResponse` construía una URI con `path: '/'`.
La IP UDP era correcta, pero el endpoint resultaba incompatible con el contrato
desktop `/vision`. La configuración manual podía incluir `/vision` mientras el
fallback UDP seguía intentando `/`. Ajustes y SharedPreferences aceptaban y
recuperaban ese endpoint histórico sin migrarlo; los tests y la documentación
también daban `/` por válido. No existía una normalización común.

Además se encontraron dos problemas que ocultaban el diagnóstico:

- `WebSocketChannel.connect` de `web_socket_channel 3.0.3` usa
  `AdapterWebSocketChannel` y `web_socket 1.0.1`. Su adaptador IO captura el
  `dart:io WebSocketException` y crea otra excepción con solo `e.message`,
  perdiendo `httpStatusCode`. El controlador tampoco conservaba el stack y al
  terminar discovery reemplazaba la causa por un error genérico.
- Cerrar el sink sin esperar su cierre no cancelaba explícitamente el
  `WebSocket.connect` nativo pendiente. El reemplazo podía comenzar mientras el
  handshake anterior todavía se resolvía.

No se dispone del error original de la sesión física descrita en el prompt.
Estos defectos están comprobados en el código y cubiertos por pruebas; no se
afirma que expliquen por sí solos un fallo físico que ya utilizara `/vision`.
El usuario indicó que Vision está apagado y que no desea depurar la LAN ahora.

## URI antes y después

```text
ANTES (discovery y configuración histórica):
ws://192.168.137.233:8765/

DESPUÉS (discovery, manual, persistencia, arranque y reconexión):
ws://192.168.137.233:8765/vision

scheme   = ws
host     = 192.168.137.233
port     = 8765
path     = /vision
query    = vacío; hasQuery = false
fragment = vacío; hasFragment = false
```

`VisionEndpoint` es la única fuente de construcción y normalización. Recibe el
host y puerto de discovery o parsea el valor manual. Migra las formas antiguas
`/`, `/vision/` y `/#/vision`; rechaza HTTP, HTTPS, WSS, otros paths, query,
fragmentos arbitrarios, credenciales y puertos inválidos. No degrada TLS a WS.
El cliente nativo vuelve a validar inmediatamente antes de abrir el socket.

UDP conserva exactamente `BLANQUITA_VISION_DISCOVER` y
`BLANQUITA_VISION_HERE:8765`, puerto 4211. El host se obtiene exclusivamente
del origen del datagrama y el puerto del anuncio validado, sin extraer IP del
payload ni escanear subredes.

## Implementación WebSocket

Antes: `WebSocketChannel.connect(Uri)` → adaptador de `web_socket` →
`dart:io WebSocket.connect`.

Ahora en Mobile: `RemoteVisionService` → `VisionSession` → transporte nativo
`dart:io WebSocket.connect`, con `HttpClient` exclusivo y conexión TCP propia.
No cambian el protocolo ni los frames JSON. La propiedad de la conexión permite
cancelar TCP/upgrade y destruir el socket anterior; el controlador espera el
cierre antes de abrir otro. Los tests conservan inyección de canales.
El navegador conserva su adaptador WebSocket mediante importación condicional.

La aparición de `http://…/#` dentro de una excepción no demuestra por sí sola
una transformación incorrecta en Mobile. El SDK Dart 3.12.2 construye internamente
una URI HTTP para el upgrade, en `_http/websocket_impl.dart`; las excepciones de
upgrade usan esa URI. Las pruebas de HTTP 400/403/404/426 verifican que la entrada
es `ws://…/vision` y que el servidor recibe `/vision`, aunque el mensaje nativo
incluya `http://`. El API público requiere un esquema WebSocket:
[WebSocket.connect — documentación Dart](https://api.dart.dev/dart-io/WebSocket/connect.html).

## Diagnóstico y estados

Antes de cada apertura se registra `VISION_WS_CONNECT`: valor recibido, URI
efectiva, scheme, host, port, path, query, fragment y número de intento.
`VISION_WS_ERROR` conserva timestamp, intento, URI efectiva, estado previo,
tipo y mensaje de la excepción, stack y código HTTP si existe.

Se distinguen URI inválida, DNS, SocketException, conexión rechazada —incluido
el código Windows 1225 observado en los tests—, timeout TCP/upgrade,
HandshakeException, rechazo HTTP, WebSocketException, cleartext/network security,
JSON v1 inválido, orden de protocolo incorrecto y heartbeat vencido posterior.
`WebSocket.connect` expone el status HTTP mediante WebSocketException, pero no
headers/reason de la respuesta fallida; el diagnóstico lo indica explícitamente.

El primer error se conserva fuera del buffer de eventos para que los reintentos
no lo borren. Diagnósticos muestra IP/puerto descubiertos, URI efectiva, estado
interno, intento, último mensaje, último heartbeat, primera excepción con stack
y último error/HTTP. Los textos de diagnóstico se pueden seleccionar/copiar.

El interruptor **Diagnóstico sin reconexión automática** suspende reintentos y
reconexión al volver del segundo plano. Las acciones manuales siguen disponibles.
Al desactivarlo se restaura el backoff si la conexión sigue siendo deseada.
No hay cambios persistentes de la preferencia de reconexión por usar este modo.

```text
DISCOVERED → CONNECTING → SOCKET_CONNECTED
→ WAITING_HELLO → WAITING_READY → WAITING_HEARTBEAT → READY

Error → ERROR → espera de backoff → RECONNECTING → nuevo intento
Desconexión/cancelación/background → DISCONNECTED
```

La disponibilidad requiere, en orden, transporte abierto, `vision.hello` válido,
`vision.ready` válido y un heartbeat posterior. Un heartbeat anterior a ready,
status con ready=true o TCP abierto no completan la validación. Los callbacks de
sesiones canceladas se invalidan mediante generación y no reactivan una sesión.

Heartbeat: desktop cada 2 s; stale predeterminado al alcanzar 6 s. La preferencia
histórica de 5 s se migra a 6 s y se impide configurar un valor menor. Se conservan
ajustes explícitos mayores, hasta 60 s. El watchdog periódico solo empieza tras
validar la conexión; el timeout inicial de TCP/protocolo se diagnostica aparte.

El parser sigue usando `protocol = blanquita-vision`, `version = 1` y los ocho
tipos existentes. No se exigen campos de SPEC 2.0. Start/stop/ping conservan sus
envelopes v1 y nunca envían comandos al ESP32.

## Android

La configuración existente ya contiene `android.permission.INTERNET`,
`usesCleartextTraffic="true"` y `network_security_config` con cleartext permitido.
No se encontró evidencia de un bloqueo cleartext en esta revisión estática.
No se modificaron permisos, configuración de seguridad, Desktop ni ESP32.
No se agregaron dependencias.

## Tests y evidencia

- Suite completa: **133 passed, 0 failed, 0 skipped**.
- Revalidación posterior del ajuste de lifecycle/diagnóstico: **22 passed**.
- `flutter analyze --no-pub`: **No issues found**.
- `flutter build apk --debug --no-pub`: **correcto**.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`.
- Logs completos: `build/all-tests.log`, `build/vision-controller-tests.log`,
  `build/vision-analyze.log` y `build/vision-apk-build.log`.

Las pruebas cubren origen UDP + puerto → URI exacta, normalización manual,
migración en SharedPreferences, reconexión con `/vision`, rechazo de URLs
inválidas, connect simultáneos, espera del cierre anterior, cancelación de un
upgrade HTTP real que no responde, orden de hello/ready/heartbeat, stale a los
6 s y conservación del error original. Los rechazos HTTP 400/403/404/426 y TCP
rechazado se prueban con sockets reales de loopback.

La integración local usa un servidor de prueba que rechaza rutas distintas de
`/vision`, envía JSON v1 y heartbeat cada 2 s. El cliente nativo mantiene la
conexión **16 s**, recibe respuestas de ping, start y stop, desconecta y conecta
una segunda sesión. Este servidor es una fixture de test; no se modifica ni se
sustituye BLANQUITA Vision Desktop para aceptar rutas incorrectas.

| Verificación | Loopback local | LAN laptop + móvil |
| --- | --- | --- |
| UDP discovery | passed | no ejecutada |
| WebSocket `/vision` | passed | no ejecutada |
| `vision.hello` | passed | no ejecutada |
| `vision.ready` | passed | no ejecutada |
| Heartbeat >15 s | passed, 16 s | no ejecutada |
| `vision.ping` | passed, heartbeat correlacionado | no ejecutada |
| `vision.start` | passed, status active | no ejecutada |
| `vision.stop` | passed, status stopped | no ejecutada |
| Reconexión | passed | no ejecutada |

La prueba LAN queda pendiente por instrucción del usuario, con Vision apagado.
Por ello, el tipo, mensaje, stack y status HTTP del **handshake físico original**
son **no disponibles**. No se presenta ningún error simulado como evidencia de
esa sesión. La instrumentación necesaria queda implementada para una prueba
posterior desde Diagnósticos.

## Archivos modificados o añadidos

```text
README.md
docs/vision-client.md
docs/vision-discovery.md
docs/vision-connection-fix.md
lib/core/storage/settings_repository.dart
lib/features/diagnostics/presentation/diagnostics_screen.dart
lib/features/settings/controller/app_settings.dart
lib/features/settings/controller/settings_controller.dart
lib/features/settings/presentation/settings_screen.dart
lib/features/vision/controller/vision_controller.dart
lib/features/vision/domain/vision_endpoint.dart
lib/features/vision/domain/vision_network_failure.dart
lib/features/vision/domain/vision_state.dart
lib/features/vision/services/remote_vision_service.dart
lib/features/vision/services/vision_discovery_service.dart
lib/features/vision/services/vision_error_details.dart
lib/features/vision/services/vision_error_details_io.dart
lib/features/vision/services/vision_transport.dart
lib/features/vision/services/vision_transport_io.dart
lib/features/vision/services/vision_transport_web.dart
test/features/vision/remote_vision_service_test.dart
test/features/vision/support/vision_test_channel.dart
test/features/vision/vision_controller_test.dart
test/features/vision/vision_discovery_controller_test.dart
test/features/vision/vision_discovery_service_test.dart
test/features/vision/vision_endpoint_test.dart
test/features/vision/vision_loopback_integration_test.dart
test/features/vision/vision_native_transport_test.dart
test/features/vision/vision_settings_test.dart
test/hotfix_connection_widget_test.dart
test/widget_test.dart
```

No se hizo commit ni push.
