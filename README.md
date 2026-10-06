# BLANQUITA

Esta rama entrega **BLANQUITA Víctor**, con identificador Android
`com.example.blanquita.victor`. Puede instalarse junto a la aplicación BLANQUITA
original; cada una conserva ajustes independientes.

Aplicación Flutter de supervisión y control seguro para el cartesiano BLANQUITA.
El móvil abre dos WebSockets independientes: uno al ESP32 para control físico y
otro al Vision Server de la laptop para percepción y telemetría.

## Empezar

```sh
flutter pub get
flutter run
```

1. Conectar móvil, ESP32 y laptop a una LAN común desde los ajustes de cada equipo.
   `CARTESIANO` es la red esperada como referencia; la app no lee el SSID.
   En Ajustes y Diagnósticos, revisar primero **Wi-Fi del teléfono**: conexión
   Android observada, IPv4, señal y continuidad durante el primer plano. Ver Wi-Fi
   conectado no confirma que ESP32 y laptop sean alcanzables.
2. En Ajustes, editar **CONTROL · ESP32** con su dirección actual, por ejemplo
   `ws://192.168.10.10:81/`. No hay IP predeterminada.
3. Editar **VISIÓN · LAPTOP**, por ejemplo `ws://192.168.10.20:8765/`.
   El log más reciente indica puerto 8765; la IP aportada es `192.168.137.27`.
   Su alcance desde el móvil falló en la prueba real y aún debe resolverse.
   `0.0.0.0` es una dirección de escucha del servidor, no el destino del móvil.
4. Probar cada conexión. El control requiere `READY`; visión requiere
   `vision.ready`. Abrir un WebSocket no basta para validar el protocolo.
5. Ante un fallo, abrir Diagnósticos y pulsar **COPIAR BITÁCORA**. El texto reúne
   estado, endpoint, fase y eventos con explicación humana y detalles técnicos.

Las URLs se guardan separadamente en `connection.websocket_url` y
`vision.websocket_url`. El hotspot/router solo aporta conectividad IP.
Las reconexiones usan la URL configurada; no hay búsqueda automática de equipos.

## Control y seguridad

Un único ESP32 controla motores X/Z, pinza, sensores, secuencias y seguridad física.
Se conserva movimiento mantenido `a/d/w/s`, heartbeat `k` cada 200 ms durante
movimiento, STOP `x`, pinza `q/e`, secuencia `j`, emergencia `z` y velocidad `+/-`.
El control se bloquea sin ESP32 validado y conserva STOP al soltar, final de carrera
y respuesta segura al lifecycle. La caída de visión no bloquea el control manual.

La laptop captura y procesa cámara/IA. El móvil recibe sus reportes; visión no
manda comandos físicos al ESP32. No hay video ni procesamiento local de cámara.

## Documentación y verificación

- [Arquitectura, errores y comprobación física](docs/network-architecture.md).
- [Detección Wi-Fi, calidad y límites de estabilidad](docs/deteccion-wifi.md).
- [Prueba real: Wi-Fi conectado, servidores no alcanzables](docs/prueba-conexiones-reales.md).
- [Contrato y comportamiento del cliente de visión](docs/vision-client.md).
- [Entrega de BLANQUITA Víctor, cambios y validaciones](docs/informe-correccion-conexiones.md).

```sh
flutter analyze
flutter test
flutter build apk --debug
```

La verificación automatizada no sustituye la comprobación con el teléfono,
firmware ESP32, servidor de laptop y router/hotspot reales. El firmware `.ino` no
se encuentra en este repositorio.

## Estructura

- `lib/core`: protocolo físico, estado, WebSocket, bitácora y persistencia.
- `lib/features`: inicio, control, visión, ajustes y diagnósticos.
- `lib/shared`: componentes y superficies visuales existentes.
- `lib/app`: tema y navegación global.

Android mantiene `INTERNET` y cleartext para `ws://` local. La lectura de conexión
Wi-Fi usa `ACCESS_NETWORK_STATE` y `ACCESS_WIFI_STATE`, sin escaneo de SSID,
ubicación ni Nearby Wi-Fi. Los requisitos del SDK
instalado y futuras migraciones se explican en la guía de arquitectura.
