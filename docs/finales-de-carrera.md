# Cuatro finales de carrera en Flutter

La interfaz interpreta identificadores lógicos `X_IZQ`, `X_DER`, `Z_ARRIBA`
y `Z_ABAJO`. El ESP32 conserva la autoridad de protección física.
No se modifican firmware, GPIO, direcciones, discovery, autenticación,
puerto WebSocket 81 ni heartbeat de 200 ms.

## Lecturas y movimiento

`SENSOR:FC:<nombre>:0|1` actualiza un estado inmutable independiente:
Libre, Activado o Sin datos. Cada socket empieza sin datos; se requieren
los cuatro estados nuevos antes de habilitar movimiento manual o secuencias.
Los paquetes anteriores siguen siendo interpretados, pero el antiguo sensor
global no sustituye los cuatro estados ni anula su bloqueo por dirección.

Cada final activado bloquea su dirección. Dos extremos opuestos activados
muestran fallo y bloquean ese eje; el otro eje puede utilizarse si dispone
de datos y cumple las condiciones de sesión y control.

STOP/LIMITE detienen el heartbeat y el movimiento local cuando corresponde.
La pulsación conserva un token hasta recibir pointer-up, pointer-cancel o
retirar el widget. Soltar envía `x` incluso después del STOP del ESP32.
No hay reinicio automático al liberar un sensor. Un token antiguo no puede
detener una pulsación nueva ni enviar `x` a una sesión WebSocket distinta.

La app suspende el socket al quedar inactiva y envía STOP si hay movimiento,
secuencia o una pulsación pendiente. Todas las lecturas se invalidan.

La pinza mantiene sus condiciones existentes. Las secuencias requieren los
cuatro finales libres; STOP y emergencia dependen de una sesión válida,
independientemente de las lecturas o del bloqueo manual.

## Interfaz

Control y Diagnósticos muestran los cuatro sensores en verde (Libre), rojo
(Activado) y gris (Sin datos). Las direcciones afectadas conservan su flecha,
con rojo, candado y descripción accesible. Los avisos explican cómo retirarse
sin abrir diálogos. El feedback háptico se produce una sola vez por cambio
de Libre a Activado, respetando los ajustes de vibración y feedback de límites.

## Verificación física en Android

1. Instala `build/app/outputs/flutter-apk/app-debug.apk` y conecta con el ESP32
   en el modo que ya utilizas. Si empleas el firmware de texto, utiliza
   laboratorio con READY. En Control, espera a ver los cuatro indicadores
   verdes. Sin las cuatro lecturas nuevas, ninguna dirección debe mover.
2. Mantén la dirección de la tabla hasta que actúe su final. Confirma la
   parada física, su indicador rojo y el candado en la dirección afectada.
   Mantén el dedo un momento: no debe reiniciarse ni continuar el heartbeat.
3. Levanta el dedo. En Diagnósticos, la última orden debe ser `x`.
   Haz una pulsación nueva en la dirección de retirada; debe estar permitida.
   Al liberarse el final, su indicador vuelve a verde y desaparece el candado.

| Final | Dirección hacia el límite | Retirada tras soltar |
| --- | --- | --- |
| X izquierda | Izquierda | Derecha |
| X derecha | Derecha | Izquierda |
| Z superior | Subir Z | Bajar Z |
| Z inferior | Bajar Z | Subir Z |

4. Repite los pasos 2 y 3 para cada fila. Verifica que los demás sensores
   libres no aparecen rojos y que sus movimientos vuelven a estar disponibles
   después de soltar la pulsación detenida.
5. Comprueba STOP central y DETENER, también con un final activado.
6. Desconecta y reconecta: los cuatro indicadores deben pasar a Sin datos y
   esperar lecturas nuevas. Cambia de app durante una pulsación: debe detenerse
   y no reanudarse al volver. En claro/oscuro y pantalla pequeña, comprueba que
   los avisos se leen completos y que el mando permite desplazarse por la página.

Las pruebas automatizadas simulan además dos límites en ejes distintos,
extremos opuestos incoherentes, STOP antes de LIMITE, mensajes duplicados,
multitouch, cancelación de puntero, liberaciones antiguas y eventos V2 firmados.
La comprobación física requiere el teléfono y el robot; no la sustituye el APK.

## Archivos de esta integración

| Archivo | Cambio |
| --- | --- |
| `lib/core/protocol/esp32_protocol.dart` | Parser estricto de FC y LIMITE, compatibilidad anterior. |
| `lib/core/models/machine_state.dart` | Estados inmutables, fallos por eje y resumen compatible. |
| `lib/core/websocket/machine_controller.dart` | `canMove`, lecturas por socket, tokens de pulsación, STOP y vibración. |
| `lib/features/control/presentation/control_screen.dart` | Bloqueo por dirección, sensores y tamaños adaptables. |
| `lib/features/control/widgets/hold_to_move_button.dart` | Candado, rojo, accesibilidad y liberación del token propietario. |
| `lib/shared/widgets/final_limits_panel.dart` | Indicadores y avisos compartidos. |
| `lib/shared/widgets/page_header.dart` | Etiquetas de sección adaptables al texto ampliado. |
| `lib/features/diagnostics/presentation/diagnostics_screen.dart` | Cuatro sensores sin retirar diagnósticos existentes. |
| `lib/features/dashboard/presentation/dashboard_screen.dart` | Resumen que no presenta un límite individual como bloqueo global. |
| `test/core/protocol/esp32_protocol_test.dart` | Paquetes válidos y malformados. |
| `test/core/websocket/final_limits_controller_test.dart` | Seguridad por dirección, reconexión, heartbeat, liberación y háptica. |
| `test/core/websocket/machine_controller_test.dart` | Transporte V2 y actualización de fixtures con lecturas iniciales. |
| `test/core/websocket/esp32_native_channel_test.dart` | Telemetría inicial por WebSocket real. |
| `test/features/control/final_limits_widget_test.dart` | Rojo/candado, multitouch, cancelación, diagnósticos y responsive. |
| `test/support/final_limits_harness.dart` | Fixture de lecturas y canales de laboratorio. |
| `test/support/esp32_test_peer.dart` | Telemetría inicial opcional firmada en V2. |
| `test/hotfix_connection_widget_test.dart` | Conserva las regresiones de Ajustes con lecturas iniciales válidas. |
| `test/features/vision/vision_controller_test.dart` | Conserva la prueba de independencia Vision/ESP32 con los cuatro sensores. |
| `docs/finales-de-carrera.md` | Comportamiento y guía de validación física. |

## Validación ejecutada

- `flutter analyze`: sin incidencias.
- `flutter test`: 174 pruebas aprobadas, incluidas las regresiones existentes.
- `flutter build apk --debug`: correcto; APK en
  `build/app/outputs/flutter-apk/app-debug.apk`.
- Widgets: 320 y 390 píxeles de ancho, texto ampliado al 130 %, claro y oscuro,
  sin overflow. Incluye comprobación del estado visual y las etiquetas accesibles.
- `git diff --check`: sin errores de whitespace.

Se conservan los cambios locales existentes y la rama `feat/furuxqfurula`.
No se ha realizado commit ni push. La comprobación física en Android queda
pendiente de ejecutar con el teléfono y el ESP32.
