# BLANQUITA

Aplicación Flutter de supervisión y control seguro para el cartesiano BLANQUITA.

## Protocolo actual

- Red esperada: hotspot externo `CARTESIANO`; Android se conecta desde sus ajustes.
- Un único ESP32 en modo estación controla motores, pinza, sensores y seguridad.
- IP por DHCP; WebSocket `ws://<IP>:81/`, sin dirección fija predeterminada.
- Descubrimiento UDP en puerto `4210`: `BLANQUITA_DISCOVER` → `BLANQUITA_HERE:81`.
- Una respuesta UDP solo propone una dirección. La conexión requiere `READY`.
- Movimiento mantenido con `a/d/w/s`, heartbeat `k` cada 200 ms y STOP `x`
- Pinza `q/e`, secuencia automática `j`, emergencia `z` y velocidad `+/-`
- Sensores `SENSOR:PLATO`, `SENSOR:FINAL` y `SENSOR:ESTADO`

## Estructura

- `lib/core`: protocolo, estado, conexión WebSocket, persistencia y haptics.
- `lib/features`: dashboard, control, visión, ajustes y diagnósticos.
- `lib/shared`: superficies glass y componentes visuales reutilizables.
- `lib/app`: tema y navegación global.

La pantalla de Visión y sus interfaces están preparadas para una integración futura. No existe captura, calibración ni detección simulada en esta fase.

## Conexión y firmware

Al iniciar, la app prueba la URL guardada durante un máximo de 5 segundos esperando
`READY`. Si falla, busca por UDP durante 3 segundos (hasta 3 broadcasts), obtiene
la IP del remitente y valida su WebSocket. Guarda la nueva URL únicamente después
de `READY`. Si vuelve a cambiar la IP, la reconexión repite este flujo con esperas
de 2, 4, 8 y hasta 15 segundos entre ciclos; no hay barrido de puertos.

En Ajustes se muestran red, estado, dirección y WebSocket. Se conserva la edición
manual de la URL y se añade **Buscar ESP32**. Buscar cierra de forma segura el enlace
anterior y empieza por UDP. Los comandos de movimiento siguen bloqueados hasta
`READY`; heartbeat, STOP, emergencia y final de carrera conservan su protocolo.
No se almacena la contraseña del hotspot en Flutter.

El workspace no contiene firmware `.ino`. El cambio mínimo necesario, el protocolo
y la comprobación con hardware están en [docs/esp32-discovery.md](docs/esp32-discovery.md).

Android conserva `INTERNET` y cleartext para el WebSocket local. No se requieren
dependencias nuevas, permisos de ubicación, consulta de SSID ni configuración de
Wi-Fi desde la app. UDP está disponible en plataformas nativas con `dart:io`;
en navegador se conserva el WebSocket manual, sin búsqueda UDP.
