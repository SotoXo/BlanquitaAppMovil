# BLANQUITA

Aplicación Flutter de supervisión y control seguro para el cartesiano BLANQUITA.

## Protocolo actual

- Red local: hotspot Android, router privado u otra LAN que permita comunicación
  entre clientes; no se consulta ni se exige un SSID y no se necesita Internet.
- Un único ESP32 en modo estación controla motores, pinza, sensores y seguridad.
- IP por DHCP; WebSocket `ws://<IP>:81/`, sin dirección fija predeterminada.
- Firmware actual: activar explícitamente **Laboratorio con firmware antiguo** en
  Ajustes y guardar `ws://IP_REAL_ESP32:81/`. `READY` habilita pruebas sin autenticación.
- Discovery V2 preparado en UDP `4210`: `BLANQUITA_DISCOVER_V2` →
  `BLANQUITA_HERE_V2|deviceId|cartesian-controller|81`. Requiere nuevo firmware.
- Discovery e identidad pública no autentican. V2 exige credencial física,
  desafío/respuesta, READY firmado y comandos protegidos por sesión.
- Movimiento mantenido con `a/d/w/s`, heartbeat `k` cada 200 ms y STOP `x`
- Pinza `q/e`, secuencia automática `j`, emergencia `z` y velocidad `+/-`
- Sensores `SENSOR:PLATO`, `SENSOR:FINAL` y `SENSOR:ESTADO`

## Estructura

- `lib/core`: protocolo, estado, conexión WebSocket, persistencia y haptics.
- `lib/features`: dashboard, control, visión, ajustes y diagnósticos.
- `lib/shared`: superficies glass y componentes visuales reutilizables.
- `lib/app`: tema y navegación global.

Visión es un cliente remoto del Vision Server de la laptop. Mantiene su propio
WebSocket, controlador global y estado, independientes del ESP32. En Ajustes →
Conexión visión se configura la URL manual, reconexión, timeout y confianza mínima.
Visión prueba la URL guardada y, si falla, busca por UDP 4211. Solo un WebSocket
con `vision.ready` válido confirma y persiste el servidor. Ajustes permite Buscar
visor y Buscar dispositivos; las búsquedas ESP32/Visión son independientes.
No existe captura ni procesamiento local, video, detección simulada o movimiento
basado en visión. El contrato JSON y la validación están en
[docs/vision-client.md](docs/vision-client.md).
El contrato que debe implementar la PC Python externa está en
[docs/vision-discovery.md](docs/vision-discovery.md).
La corrección del crash al guardar URLs, el arranque sin endpoints y la
recuperación tras volver de WiFi se documentan en
[docs/connection-hotfix.md](docs/connection-hotfix.md).

## Conexión y firmware

Sin selección previa, discovery recopila candidatos durante 3 s (hasta tres
broadcasts), sin conectar al primero. El usuario selecciona y vincula su equipo.
Con identidad y credencial guardadas, se prueba la URL conocida con handshake V2;
si falla, se busca únicamente ese deviceId y se actualiza su dirección tras
autenticar. Se conservan esperas de 2, 4, 8 y hasta 15 s entre ciclos.

En laboratorio se acepta READY exclusivamente en la URL manual, sin autenticación
ni recuperación automática de otra IP mediante HERE antiguo. Si cambia la IP del
firmware actual hay que editarla. STOP, emergencia y heartbeat físico k de 200 ms
conservan sus caracteres; en V2 se encapsulan en mensajes firmados.

La clave de vinculación se guarda con `flutter_secure_storage`; la identidad
pública y la última dirección usan SharedPreferences. No se guarda la contraseña
del Wi-Fi. Android conserva INTERNET y cleartext local, sin permisos de ubicación.
El transporte nativo usa ping/pong WebSocket para detectar enlaces silenciosos;
la parada efectiva al cortar Wi-Fi depende del watchdog del ESP32.

Contrato Arduino, diagnóstico y límites: [docs/esp32-v2.md](docs/esp32-v2.md).
Pruebas, archivos y pasos exactos en Android:
[docs/esp32-android-validation.md](docs/esp32-android-validation.md).
El contrato antiguo de discovery se conserva como referencia histórica y no
autoriza control automático. No hay firmware `.ino` en este workspace.

Para desplegar con múltiples dispositivos, compilar con
`flutter build apk --debug --dart-define=BLANQUITA_MULTI_DEVICE=true`.
Esta variante bloquea laboratorio incluso con preferencias antiguas activadas.
UDP requiere plataforma nativa; en navegador se conserva URL manual, sin UDP.
V2 no está validado contra hardware hasta que Arduino implemente el mismo contrato.
