# BLANQUITA

Aplicación Flutter de supervisión y control seguro para el cartesiano BLANQUITA.

## Protocolo actual

- WiFi: `CARTESIANO_ESP32`
- WebSocket predeterminado: `ws://192.168.4.1:81/`
- Movimiento mantenido con `a/d/w/s`, heartbeat `k` cada 200 ms y STOP `x`
- Pinza `q/e`, secuencia automática `j`, emergencia `z` y velocidad `+/-`
- Sensores `SENSOR:PLATO`, `SENSOR:FINAL` y `SENSOR:ESTADO`

## Estructura

- `lib/core`: protocolo, estado, conexión WebSocket, persistencia y haptics.
- `lib/features`: dashboard, control, visión, ajustes y diagnósticos.
- `lib/shared`: superficies glass y componentes visuales reutilizables.
- `lib/app`: tema y navegación global.

La pantalla de Visión y sus interfaces están preparadas para una integración futura. No existe captura, calibración ni detección simulada en esta fase.
