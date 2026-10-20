# Discovery de Vision Server y contrato de la PC Python externa

Esta implementación modifica solo Flutter. El servidor Python se ejecutará en
otra PC y no se ha creado ni modificado código Python en este workspace.
El contrato JSON v1 existente de [vision-client.md](vision-client.md) se conserva.

## Flujo Flutter

```text
Inicio / Conectar / Reconectar
  → probar visionWebsocketUrl persistida
  → abrir WebSocket /vision y esperar hello + ready + heartbeat (hasta 8 s)
  → si falla: broadcast UDP 4211 (hasta 3 s / 3 solicitudes)
  → candidato desde IP origen del datagrama
  → abrir ws://IP-origen:8765/vision y exigir hello + ready + heartbeat (hasta 8 s)
  → si valida: usar la sesión y persistir la nueva URL
  → si falla: conservar URL manual y mostrar estado/error
  → con auto-reconnect: repetir ciclo tras backoff 1/2/4/8/16/30 s
```

Una sesión se marca conectada únicamente después de abrir el transporte y recibir
`vision.hello`, `vision.ready` válido y después `vision.heartbeat`.
`vision.status` con ready=true, una respuesta UDP y un WebSocket abierto no
sustituyen este handshake. `ready:false`
no valida. Los mensajes requieren protocolo, versión, ID, timestamp y payload
correctos. Una confirmación tardía de una sesión cancelada se ignora.

**Buscar visor** inicia por UDP sin probar primero la URL guardada. **Buscar
dispositivos** lanza las búsquedas ESP32 y visión por separado; el fracaso de una
no cancela la otra. Buscar ESP32 conserva el comportamiento de seguridad existente
de MachineController. El módulo Vision nunca llama a MachineController.

La pérdida de heartbeat también cierra la sesión de visión y activa recuperación
con backoff. Se utiliza el timeout configurado (6 s predeterminado, 6–60 s);
el estado se revisa cada segundo. La reconexión usa primero la URL conocida y
después discovery, permitiendo cambiar entre redes 172.20.10.x, 10.42.193.x y
192.168.137.x sin escaneo de subredes o puertos. El contador de backoff se reinicia
cuando el servidor valida el handshake.

Desconectar, cambios de URL, lifecycle y dispose cancelan discovery/handshake
pendientes. Si el usuario desconecta, se cancelan los reintentos. La URL manual
sigue editable y no se borra al fallar discovery. Una búsqueda válida sí actualiza
visionWebsocketUrl según el contrato solicitado. En navegador, UDP no está
disponible; permanece el fallback mediante URL manual.

## Lo que debe implementar Python en la otra PC

### 1. Responder UDP IPv4

| Propiedad | Valor obligatorio |
| --- | --- |
| Dirección de escucha | `0.0.0.0` o interfaces LAN pertinentes |
| Puerto UDP | `4211` |
| Solicitud exacta | `BLANQUITA_VISION_DISCOVER` |
| Respuesta exacta | `BLANQUITA_VISION_HERE:8765` |
| Destino de la respuesta | IP **y puerto** origen de la solicitud recibida |
| Codificación | ASCII/UTF-8, sin salto de línea, espacios ni terminador NUL |

El móvil usa un puerto UDP local efímero: la respuesta debe volver a ese puerto,
no al 4211 del móvil. Ignorar cualquier solicitud cuyo contenido no sea exacto.
No incluir IP, URL, JSON u otros campos en la respuesta.

Ejemplo: un datagrama válido recibido por Flutter desde `192.168.137.115`
produce `ws://192.168.137.115:8765/vision`. La IP se toma exclusivamente del remitente
del datagrama, jamás del contenido. La respuesta anuncia un candidato y no
demuestra disponibilidad del servidor.

El responder debe convivir con WebSocket sin bloquear el event loop. La futura
implementación puede usar `asyncio.DatagramProtocol` y
`loop.create_datagram_endpoint`, respondiendo con `transport.sendto(respuesta,
addr)` en `datagram_received`. No hacer `recvfrom` bloqueante ni usar `time.sleep`
en el loop. Cerrar el transporte UDP durante el apagado del servidor.

### 2. WebSocket en TCP 8765

El contrato existente escucha en `0.0.0.0:8765` o en la IP LAN accesible y acepta
exactamente la ruta `/vision`. Esta corrección solo modifica Mobile.
`127.0.0.1` como única interfaz no permite acceso desde el teléfono. Discovery
anuncia específicamente el endpoint `ws://<remitente>:8765/vision`; una configuración
manual usa el mismo constructor y contrato, sin otra ruta ni fragmento.

Al aceptar **cada** cliente, enviar en orden:

1. `vision.hello`.
2. `vision.ready` una vez disponible el servicio del protocolo, sin esperar
   `vision.start`. Debe llegar antes del timeout de 8 s del móvil.
3. `vision.status` con los datos reales disponibles.
4. `vision.heartbeat` periódicamente mientras el cliente siga conectado.

Un servicio sin cámara configurada puede comunicar ready del protocolo y estados
`unavailable`; nunca inventar cámara, FPS, objeto o coordenadas.

### 3. JSON v1 — sin cambios

Cada mensaje debe ser un frame WebSocket **de texto** con este envelope completo:

```json
{
  "protocol": "blanquita-vision",
  "version": 1,
  "type": "vision.ready",
  "messageId": "identificador-unico-por-mensaje",
  "timestamp": "2026-10-06T15:00:00.000Z",
  "payload": {}
}
```

Obligatorios: protocol exacto, version **entera** 1, type, messageId no vacío,
timestamp ISO-8601 válido y payload objeto. Preferir timestamps UTC con `Z`.
UUID es válido para messageId, aunque Flutter no exige ese formato.

Para `vision.hello`, usar el mismo envelope con type=`vision.hello` y payload
vacío o telemetría real. Para `vision.ready`, `{}` significa listo; también es
válido `{"ready": true}`. El texto crudo `READY` del ESP32 no es válido aquí.

Ejemplo de status sin subsistemas configurados:

```json
{
  "protocol": "blanquita-vision",
  "version": 1,
  "type": "vision.status",
  "messageId": "status-1",
  "timestamp": "2026-10-06T15:00:00.010Z",
  "payload": {
    "ready": true,
    "cameraStatus": "unavailable",
    "detectorStatus": "unavailable",
    "calibrationStatus": "unavailable"
  }
}
```

Campos opcionales: cameraName, fps, latency en ms y alerts. Omitir datos no
disponibles. Los modelos y validaciones de reportes permanecen iguales.

### 4. Heartbeat y comandos del móvil

Enviar heartbeat desde que se conecta el cliente, incluso si el detector está
detenido. El contrato fija un heartbeat cada **2 s**, con stale a los **6 s**. No hacer
depender heartbeat de frames, detecciones, cámara o comandos `vision.start`.
Enviar con envelope v1 y type=`vision.heartbeat`, payload `{}`.

Flutter puede enviar `vision.start`, `vision.stop` y `vision.ping`, siempre con
envelope v1 y payload vacío. Start/stop se aplican exclusivamente al subsistema
de visión: detener el detector no detiene el heartbeat del servidor.

Para medir latencia RTT, responder a ping con heartbeat y payload.replyTo igual
al messageId del ping:

```json
{
  "protocol": "blanquita-vision",
  "version": 1,
  "type": "vision.heartbeat",
  "messageId": "heartbeat-2",
  "timestamp": "2026-10-06T15:00:00.500Z",
  "payload": {"replyTo": "messageId-recibido-en-vision.ping"}
}
```

El servidor debe permitir reconexiones y repetir hello/ready/status para cada
nueva sesión, cancelar tareas por cliente al cerrar y tolerar que el móvil cierre
el socket durante discovery, cambio de URL o salida al segundo plano. Nunca
enviar comandos a motores ni conectar directamente al ESP32 desde este flujo.

### 5. Red de la PC externa

PC y móvil deben compartir una LAN con comunicación entre clientes. El firewall
de la PC debe permitir entrada UDP 4211 y TCP 8765. La red debe transportar el
broadcast IPv4; si lo bloquea o aísla clientes, discovery no funcionará y habrá
que usar la URL manual en una red que permita el WebSocket. No se requiere Internet.

## Archivos y verificación Flutter

Servicio nuevo: `lib/features/vision/services/vision_discovery_service.dart`.
Reutiliza únicamente DiscoveryTransport genérico, con instancia y ciclo de vida
propios. Esp32DiscoveryService y MachineController no se modifican. El parser,
modelos, comandos físicos y contrato JSON existentes tampoco se modifican.

Controlador: valida transporte + hello + ready + heartbeat, ordena URL/discovery, persiste solo tras
validación y gestiona backoff, timeout, cancelación y sesiones obsoletas.
Ajustes muestra estado, dirección detectada, URL y Buscar visor, conservando el
panel ESP32. Visión y Diagnósticos reflejan endpoint y estado de discovery.

Pruebas: UDP válido/incorrecto, IP origen, mensajes con IP inyectada rechazados,
URL conocida válida/obsoleta, candidato sin ready, envelope inválido, DHCP entre
tres redes, backoff, cancelación/confirmación tardía, heartbeat perdido, búsquedas
simultáneas, independencia Machine/Vision e interfaz de Buscar dispositivos.

Las pruebas de UDP/WebSocket usan loopback y dobles de transporte; la PC Python
externa y el hardware no están accesibles desde este workspace.

Validación completada el 6 de octubre de 2026:

- `flutter analyze`: sin incidencias.
- `flutter test`: 78 pruebas correctas, incluidas todas las pruebas ESP32 existentes.
- `flutter build apk --debug`: correcto (assembleDebug: 6,2 s).
- APK: `C:\Users\Usuario\Documents\Flutter proyects\blanquita\build\app\outputs\flutter-apk\app-debug.apk`.
- Ninguna dependencia añadida. Sin commit ni push.
