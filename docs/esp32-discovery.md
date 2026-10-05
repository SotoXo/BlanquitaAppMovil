# Red de BLANQUITA y complemento UDP del firmware

El hotspot externo `CARTESIANO` conecta el teléfono con Flutter y **un solo ESP32**
en `WIFI_STA`. Ese ESP32 maneja motores X/Z, servo, plato, final de carrera,
secuencia, heartbeat y WebSocket. No existe otro canal o dispositivo para sensores.
La contraseña se configura fuera de Flutter. DHCP determina la dirección del ESP32.

## Protocolo exacto

| Operación | Dirección / contenido |
| --- | --- |
| Solicitud | UDP broadcast IPv4 `255.255.255.255:4210`, texto UTF-8 `BLANQUITA_DISCOVER` |
| Respuesta | UDP unicast a la IP y puerto origen de la solicitud, texto `BLANQUITA_HERE:81` |
| Dirección candidata | `ws://<IP origen de la respuesta UDP>:81/` |
| Validación | El WebSocket existente envía `READY` dentro de 5 segundos |

Los textos UDP no llevan espacios, saltos de línea ni terminador NUL. El puerto
4210 es el puerto de discovery acordado para esta implementación; el WebSocket
mantiene el puerto 81. Flutter escucha en un puerto UDP efímero, por eso el firmware
debe responder al **puerto origen**, no a un puerto fijo en el teléfono.
Se rechazan contenido incorrecto, otros puertos WebSocket y texto UTF-8 inválido.
La IP procede siempre del datagrama, nunca del texto de respuesta.

## Código mínimo para incorporar al `.ino` existente

No hay `.ino` en este workspace. Agregar este bloque al firmware que ya se conecta
como estación y ya mantiene su WebSocket. No sustituir su código físico o de seguridad.

```cpp
#include <WiFi.h>
#include <WiFiUdp.h>
#include <cstring>

static WiFiUDP blanquitaDiscoveryUdp;
static bool blanquitaDiscoveryStarted = false;
static constexpr uint16_t BLANQUITA_DISCOVERY_PORT = 4210;
static constexpr char BLANQUITA_DISCOVER_REQUEST[] = "BLANQUITA_DISCOVER";
static constexpr char BLANQUITA_DISCOVER_REPLY[] = "BLANQUITA_HERE:81";

void pollBlanquitaDiscovery() {
  if (WiFi.status() != WL_CONNECTED) {
    if (blanquitaDiscoveryStarted) blanquitaDiscoveryUdp.stop();
    blanquitaDiscoveryStarted = false;
    return;
  }

  if (!blanquitaDiscoveryStarted) {
    blanquitaDiscoveryStarted =
        blanquitaDiscoveryUdp.begin(BLANQUITA_DISCOVERY_PORT) == 1;
    if (!blanquitaDiscoveryStarted) return;
  }

  const int packetSize = blanquitaDiscoveryUdp.parsePacket();
  if (packetSize <= 0) return;

  const IPAddress requester = blanquitaDiscoveryUdp.remoteIP();
  const uint16_t requesterPort = blanquitaDiscoveryUdp.remotePort();
  char packet[32];
  const int bytesRead = blanquitaDiscoveryUdp.read(packet, sizeof(packet));
  const size_t expectedLength = sizeof(BLANQUITA_DISCOVER_REQUEST) - 1;
  if (packetSize != static_cast<int>(expectedLength) ||
      bytesRead != static_cast<int>(expectedLength) ||
      std::memcmp(packet, BLANQUITA_DISCOVER_REQUEST, expectedLength) != 0) {
    return;
  }

  if (blanquitaDiscoveryUdp.beginPacket(requester, requesterPort) == 1) {
    blanquitaDiscoveryUdp.write(
        reinterpret_cast<const uint8_t*>(BLANQUITA_DISCOVER_REPLY),
        sizeof(BLANQUITA_DISCOVER_REPLY) - 1);
    blanquitaDiscoveryUdp.endPacket();
  }
}
```

Añadir `pollBlanquitaDiscovery();` al `loop()` existente, junto a la atención de
WebSocket y seguridad. Atiende como máximo un datagrama por vuelta, sin `delay`,
esperas de conexión ni comandos de motor. Inicializa UDP cuando Wi-Fi está conectado
y vuelve a iniciarlo después de una desconexión de Wi-Fi. `READY` sigue siendo
responsabilidad del manejador WebSocket existente al aceptar un cliente.

## Flujo, reconexión y configuración manual

1. Probar la URL conocida/persistida, si existe, y esperar `READY`.
2. Si falla, enviar hasta tres broadcasts (separados por un segundo) en una búsqueda
   acotada a tres segundos. No se escanean direcciones ni puertos.
3. Probar el candidato mediante el único WebSocket y esperar `READY`.
4. Guardar la nueva URL solo después de la validación. Si falla, mostrar
   «No encontrado» y permitir edición manual y búsqueda explícita en Ajustes.
5. Tras perder un enlace, repetir con backoff 2/4/8/15 segundos cuando la reconexión
   automática está habilitada. Desconectar manualmente cancela intentos y búsqueda.

Los dispositivos pueden anunciar el texto UDP sin ser BLANQUITA; el mensaje
`READY` valida compatibilidad con el protocolo existente, no autentica el hardware.
No se transmiten comandos antes de ese mensaje. No cambian `a/d/w/s`, `x`, `k`
(200 ms durante movimiento), `q/e`, `j`, `z`, `+/-` ni los mensajes de sensores.

## Android

El Flutter SDK instalado usa compile/target SDK **36**. El manifiesto ya declara
`INTERNET`, `usesCleartextTraffic=true` y una configuración de seguridad que permite
`ws://` local. Esta búsqueda usa UDP broadcast/unicast, sin multicast, lectura de
SSID ni control del Wi-Fi: no se añaden permisos de ubicación, Nearby Wi-Fi o
CHANGE_WIFI_MULTICAST_STATE.

Para target SDK 36 o inferior, `INTERNET` concede acceso LAN; Android 16 permite
probar restricciones LAN mediante opt-in. Al migrar a target SDK 37 o superior será
necesario declarar y solicitar `ACCESS_LOCAL_NETWORK` en runtime antes de abrir
UDP o WebSocket, según la [documentación oficial de Android](https://developer.android.google.cn/privacy-and-security/local-network-permission?hl=en).
No se eleva el target SDK por esta tarea.

La implementación usa [RawDatagramSocket de Dart](https://api.dart.dev/dart-io/RawDatagramSocket-class.html),
activa broadcast IPv4 y cierra sockets y temporizadores al terminar/cancelar.
En navegador no existe UDP raw; la edición manual de WebSocket sigue disponible.

## Comprobación con hardware

- Conectar ESP32 y teléfono al mismo hotspot CARTESIANO y cargar el bloque UDP.
- Con URL vacía, abrir BLANQUITA: buscar, recibir `READY`, mostrar dirección y guardar URL.
- Reiniciar la app: comprobar que prueba primero la URL guardada.
- Cambiar la concesión DHCP del ESP32: verificar recuperación automática y nueva URL.
- Sin UDP disponible, introducir una URL válida en Ajustes y verificar `READY`.
- Verificar heartbeat, STOP al soltar/cambiar lifecycle, emergencia y bloqueo por final.

El hotspot debe permitir comunicación entre clientes y broadcast. Si bloquea solo
broadcast, se puede usar la URL manual; si aísla clientes, también bloqueará WebSocket
y debe ajustarse el hotspot. La validación de software no sustituye esta prueba real.

## Inventario y validación de esta adaptación

Archivos modificados (10):

- `lib/core/websocket/machine_controller.dart`: flujo URL → UDP → READY, cancelación y reconexión.
- `lib/core/storage/settings_repository.dart`: elimina la IP fija por defecto y conserva la persistida.
- `lib/features/settings/controller/app_settings.dart`: URL inicial vacía.
- `lib/features/settings/presentation/settings_screen.dart`: red, estado, dirección, búsqueda y edición manual.
- `lib/features/control/presentation/control_screen.dart`: nombre de red CARTESIANO.
- `lib/features/dashboard/presentation/dashboard_screen.dart`: único ESP32 y dirección actual.
- `android/app/src/main/res/xml/network_security_config.xml`: comentario adaptado al hotspot externo.
- `README.md`: arquitectura y flujo actualizados.
- `test/core/protocol/esp32_protocol_test.dart`: regresión del protocolo de comandos y seguridad.
- `test/widget_test.dart`: información de red y acceso al editor manual.

Archivos nuevos (6):

- `lib/core/network/esp32_discovery_service.dart`: protocolo y construcción de URL candidata.
- `lib/core/network/discovery_transport_io.dart`: transporte UDP nativo acotado y cancelable.
- `lib/core/network/discovery_transport_stub.dart`: fallback sin UDP para navegador.
- `test/core/network/esp32_discovery_service_test.dart`: respuestas, rechazo, UDP, timeout y cancelación.
- `test/core/websocket/machine_controller_test.dart`: READY, persistencia, DHCP, manual, reconexión y seguridad.
- `docs/esp32-discovery.md`: esta guía y el complemento mínimo de firmware.

No se agregaron dependencias ni permisos Android. El parser y los comandos de
producción permanecen iguales. Validación final: `flutter analyze` sin incidencias,
`flutter test` con **22 pruebas aprobadas**, y `flutter build apk --debug` completado.
APK generado: `build/app/outputs/flutter-apk/app-debug.apk`. No se hizo commit ni push.
