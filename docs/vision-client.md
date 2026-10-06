# Visor Inteligente — cliente Flutter, fase 1

Decisiones consultadas antes de implementar:

- [APP_MOVIL_BLANQ_V2.md](https://github.com/Josue-EC16/Visor_Inteligente_BLQ/blob/main/APP_MOVIL_BLANQ_V2.md)
- [ARQUITECTURA_CONEXION.md](https://github.com/Josue-EC16/Visor_Inteligente_BLQ/blob/main/ARQUITECTURA_CONEXION.md)

La laptop percibe, el móvil supervisa y el ESP32 ejecuta y protege. En esta fase
visión informa exclusivamente. No hay AutomationCoordinator, SafetyGate, control
de motores desde visión, procesamiento de cámara, IA ni discovery de laptop.

## Arquitectura

```text
Laptop WebSocket → RemoteVisionService / VisionSession
                → VisionProtocolParser / modelos
                → VisionController (ChangeNotifier)
                → VisionState → Provider → pantallas

MachineController → WebSocket ESP32 configurado → READY

Ambos controladores → ConnectionLog → Diagnósticos / portapapeles
```

VisionController se crea en main y vive con BlanquitaApp. Cambiar entre Inicio,
Control, Visión y Ajustes conserva la sesión. El app lifecycle invoca cada
controlador por separado y conserva el comportamiento de seguridad del ESP32.

## Conexión

1. Configurar URL en Ajustes → Conexión visión, por ejemplo
   `ws://<IP-laptop>:8765/` o `wss://<host>/vision`. No hay IP predeterminada.
   El log de servidor aportado después indica escucha en `0.0.0.0:8765`;
   usar su IP LAN real como destino, no `0.0.0.0`. Esta evidencia actual reemplaza
   el puerto 6580 mencionado previamente. No se utiliza el anuncio de descubrimiento
   del servidor para localizar la laptop: se configura su URL WebSocket.
2. Pulsar Conectar. Se abre un socket exclusivo de visión con timeout de 8 s.
3. WebSocket conectado y Vision Server ready son estados distintos. La apertura
   del transporte inicia la espera de `vision.ready`, sin asumir validación.
   `vision.ready` con payload vacío comunica ready; `ready: false` lo revoca.
4. Recibir JSON, validar envelope y campos conocidos, actualizar telemetría.
5. Iniciar visor / Detener visor / Ping solo envían `vision.start`,
   `vision.stop`, `vision.ping`; no cambian la telemetría de forma optimista.
6. Desconectar cancela los reintentos. Cambiar URL reemplaza la sesión activa y
   limpia la telemetría anterior. Volver a abrir la app conecta si hay una URL.

Una conexión puede estar activa mientras la otra está desconectada. Un reporte,
error, heartbeat vencido o desconexión de visión jamás llama a MachineController.

## Contrato JSON v1

Todos los mensajes usan un envelope obligatorio:

```json
{
  "protocol": "blanquita-vision",
  "version": 1,
  "type": "vision.report",
  "messageId": "uuid-o-identificador-unico",
  "timestamp": "2026-10-06T10:30:00Z",
  "payload": {
    "detected": true,
    "object": "pieza",
    "position": {"x": 145.2, "z": 78.4},
    "confidence": 0.96,
    "cameraStatus": "operative",
    "calibrationStatus": "valid",
    "detectorStatus": "active",
    "alerts": []
  }
}
```

`messageId` es texto no vacío, no se exige formato UUID. Timestamp es ISO-8601
con fecha y hora válidas. Se recomienda UTC con `Z` o un offset explícito. También
se acepta la forma sin zona usada en el documento de arquitectura; se interpreta
en la zona local del móvil. Las coordenadas se muestran en las unidades enviadas
por el servidor: el cliente no presupone ni convierte a mm.

| Mensaje laptop → móvil | Payload reconocido |
| --- | --- |
| `vision.hello` | Telemetría opcional, sin asumir ready |
| `vision.ready` | `ready` opcional; ausencia significa true; telemetría opcional |
| `vision.status` | `ready`, `cameraStatus`, `cameraName`, `detectorStatus`, `calibrationStatus`, `fps`, `latency`, `alerts` |
| `vision.report` | `detected`, `object`, `position: {x, z}`, `confidence`, telemetría y `alerts` |
| `vision.error` | `message`, `code`; ausencia muestra error genérico |
| `vision.heartbeat` | Telemetría opcional y `replyTo` opcional para responder al ID de `vision.ping` |
| `camera.status` | `status`, `name`; telemetría opcional |
| `calibration.status` | `status`; telemetría opcional |

Los estados son textos del servidor, sin inventar valores. Vocabulario recomendado:

- Cámara: `operative`, `disconnected`, `error`, `unavailable`.
- Detector: `active`, `stopped`, `error`, `unavailable`.
- Calibración: `valid`, `pending`, `invalid`, `unavailable`.

Los estados desconocidos se muestran literalmente para diagnóstico. Los campos
opcionales ausentes/null de telemetría mantienen el último valor de la sesión;
usar `unavailable` para indicar explícitamente indisponibilidad. Cada reporte es
una instantánea nueva: la ausencia de posición elimina las coordenadas previas.
`position: null` y `{}` producen PositionEstimate null; un eje ausente queda null.
Un reporte con `detected: false` no expone una posición como detección actual.

Confianza debe ser numérica finita en [0, 1]; X/Z números finitos; FPS y latencia
números no negativos; detected/ready booleanos; alerts lista de textos. Un campo
conocido mal tipado rechaza el mensaje completo sin sustituir el último reporte
válido. Campos adicionales son ignorados. Tipos desconocidos se registran y se
ignoran. JSON inválido, envelope incorrecto, versiones no soportadas y timestamps
inválidos se registran y se reflejan como error sin terminar la conexión.

Reportes con timestamp igual o anterior al último se ignoran, evitando sustituir
coordenadas nuevas por datos repetidos o atrasados. Para cada actualización el
servidor debe producir un timestamp posterior.

Los únicos mensajes salientes tienen el mismo envelope y payload vacío:

```json
{
  "protocol": "blanquita-vision",
  "version": 1,
  "type": "vision.ping",
  "messageId": "mobile-1791282600000000-1",
  "timestamp": "2026-10-06T10:30:00.000Z",
  "payload": {}
}
```

`vision.start` y `vision.stop` usan exactamente el mismo formato. IDs salientes
combinan reloj en microsegundos y contador por controlador. No se admiten comandos
crudos ni payload de motores mediante el API de transporte.

## Heartbeat, reportes y latencia

- `lastHeartbeat` registra recepción local de un `vision.heartbeat` válido.
- Hasta el primer heartbeat, el timeout empieza al conectar el socket.
- El estado se revisa cada segundo. Tras superar el timeout, `stale = true` y
  ready efectivo es false. El socket permanece abierto para recuperar heartbeat.
- Reportes/status no sustituyen al heartbeat. Un heartbeat fresco elimina stale,
  pero no hace reciente un reporte antiguo.
- `reportAge` usa el timestamp del reporte; `reportStale` utiliza el mismo timeout
  configurado en esta fase. Sin reportes la edad es null. Sin conexión, los datos
  anteriores se conservan como históricos caducados hasta la siguiente sesión.
- La edad requiere relojes laptop/móvil sincronizados. La latencia no se calcula
  restando sus relojes: se usa `payload.latency` (ms) o RTT de un heartbeat cuyo
  `replyTo` coincide con un ping enviado por el móvil.
- Se envía ping al conectar y cada timeout/2, con intervalo mínimo de 500 ms.
  Como máximo se conservan 16 correlaciones pendientes.
- No se detiene ni desconecta el ESP32 ante stale de visión.

## Reconexión y lifecycle

Con reconexión habilitada, errores de transporte y cierre remoto reintentan en
1, 2, 4, 8, 16 y hasta 30 s. El contador se reinicia al recibir `vision.ready`,
no al abrir TCP ni al recibir un heartbeat. Los cambios de ajuste y desconexión manual cancelan
reintentos pendientes. Intentos obsoletos no pueden reactivar una sesión cancelada.

Al salir del primer plano se cierra visión y se marca stale. Al volver se intenta
conectar si la sesión era deseada y la reconexión está habilitada. Si el usuario
había desconectado, no se abre automáticamente.

Editar explícitamente la URL inicia una conexión al nuevo endpoint aunque la
reconexión automática esté desactivada. Si la edición ocurre en segundo plano,
ese intento explícito se conserva para el siguiente regreso al primer plano.
Desconectar manualmente vuelve a cancelar el deseo de conexión.

## Ajustes y UI

SharedPreferences existentes persisten:

| AppSettings | Clave | Predeterminado |
| --- | --- | --- |
| `visionWebsocketUrl` | `vision.websocket_url` | vacío |
| `visionAutoReconnect` | `vision.auto_reconnect` | true |
| `visionHeartbeatTimeout` | `vision.heartbeat_timeout_ms` | 5000 ms |
| `visionMinimumConfidence` | `vision.minimum_confidence` | 0.8 |

Timeout permitido: 1–60 s; confianza: 0–1. La confianza mínima únicamente genera
un aviso; no elimina reportes ni autoriza acciones físicas. Se eliminaron los
ajustes antiguos de cámara local/FPS objetivo y las interfaces CameraFrameSource,
VisionDetector y VisionService. PositionEstimate se conserva sin cambios.

Visión muestra conexión, ready, cámara/nombre, detector, calibración, FPS, latencia,
objeto, coordenadas, confianza, edad y alertas usando las superficies Liquid Glass
existentes. Sin reportes muestra **Sin datos de visión**. Inicio añade un resumen
breve. Diagnósticos separa **ESP32 · CONTROL** y **Laptop · VISIÓN** con tarjetas de
transporte y protocolo. La bitácora central reúne ambos canales, eventos de sistema,
error humano y detalle técnico desplegable. **COPIAR BITÁCORA** exporta estado
y eventos; **LIMPIAR** borra eventos en memoria sin alterar conexiones. No se usa
SharedPreferences como historial. Ver la [guía de arquitectura](network-architecture.md).

La recepción de telemetría actualiza el estado en cada mensaje válido. Para evitar
que el historial central desplace los fallos con tráfico repetido, TX `vision.ping`,
RX `vision.heartbeat` y RX `vision.report` se registran por muestreo: la primera
entrada y luego como máximo una cada 10 segundos por tipo, con `session_count`
acumulado en el detalle técnico. El muestreo no reduce la frecuencia de envío,
recepción ni actualización de telemetría. Los errores y cambios de conexión
mantienen registro individual. La bitácora central conserva hasta 240 entradas.

## Validación

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Las pruebas incluyen parser, heartbeat/stale, reportes parciales, reconexión,
lifecycle, cancelación de handshake, ajustes, ambos controladores independientes,
WebSocket real en loopback y navegación. Las pruebas del ESP32 se conservan.
La prueba loopback no sustituye la comprobación final con la laptop y el robot.

Los resultados actuales y la comprobación con hardware se mantienen en
[network-architecture.md](network-architecture.md). Los conteos/rutas de
compilaciones históricas no verifican la implementación de esta rama.
