# Validación ESP32 y Android

## Alcance real

Implementado en Flutter: URL manual con firmware antiguo en laboratorio explícito;
READY con timeout, reconexión, heartbeat k/200 ms, STOP y emergencia; identidad
persistente, discovery V2 con ventana completa, selección, credencial segura,
desafío/respuesta y protección de comandos/eventos. Se conserva el hotfix de Ajustes.
No se cambió Python Vision Server ni los comandos físicos.

El código antiguo puede utilizarse hoy con un hotspot que permita tráfico entre
clientes. Esto es compatibilidad de software comprobada con pruebas automatizadas;
**no es una prueba física del ESP32**. Sin discovery V2 el usuario actualiza la
URL cuando DHCP cambia la IP. No hay IP ni nombre de Wi-Fi obligatorios.

Pendiente con hardware: verificar que el firmware antiguo responde a ping/pong,
lecturas de sensores y watchdog real; implementar exactamente el contrato Arduino
V2; probar exclusión de dos teléfonos, claves físicas, DHCP y varios equipos en
el router. La app por sí sola no puede imponer exclusividad en firmware antiguo.

## Instalación y prueba actual en un celular Android

1. Conectar el ESP32 en WIFI_STA al hotspot elegido. Obtener **su IP real** desde
   el monitor serie (`WiFi.localIP()`) o la lista DHCP del hotspot. No usar la IP
   del teléfono, la laptop ni la puerta de enlace. No hay un ESP32 de sensores.
2. Conectar el teléfono de prueba a ese mismo hotspot. En Android, conservar la
   conexión cuando avise que no hay Internet. El hotspot debe permitir tráfico
   entre clientes; si lo bloquea, usar otro hotspot o un router con aislamiento
   de clientes/AP desactivado. Un segundo teléfono como cliente suele facilitar
   el ensayo; el comportamiento del teléfono que aloja el hotspot depende de su sistema.
3. Habilitar depuración USB, autorizar el PC y ejecutar desde este repositorio:

   ```powershell
   flutter devices
   flutter build apk --debug
   adb install -r "build\app\outputs\flutter-apk\app-debug.apk"
   ```

   Si hay varios equipos ADB, usar `adb -s SERIAL install -r ...`. Como alternativa,
   copiar `build/app/outputs/flutter-apk/app-debug.apk` al teléfono e instalarlo,
   o ejecutar `flutter run -d ID_ANDROID`.
4. Abrir BLANQUITA → Ajustes → **Mi ESP32**. Activar **Laboratorio con firmware
   antiguo**. Este modo está desactivado inicialmente. No seleccionar/vincular un
   deviceId ficticio para firmware antiguo; si ya hay selección V2, desvincularla.
5. Tocar WebSocket, introducir `ws://IP_REAL_ESP32:81/` y Guardar. Esperar READY
   hasta 5 s. Debe aparecer WebSocket conectado y **Laboratorio: READY sin
   autenticación**. No debe aparecer «Autorizado V2».
6. En Control, probar a/d/w/s mantenidos y liberación → x. Comprobar k cada 200 ms
   con logs serie del ESP32. Probar STOP x, emergencia z, pinza q/e, velocidad +/-
   y secuencia j; verificar plato y final de carrera con el mecanismo preparado
   para pruebas controladas. No se reanuda movimiento automáticamente al reconectar.
7. Mantener la conexión al menos 15 s sin mover para comprobar ping/pong; probar
   reconexión con la misma IP reiniciando el ESP32. Con corte de Wi-Fi, Flutter
   cancela movimiento/heartbeat e intenta STOP si queda transporte. Verificar
   físicamente el watchdog local: no puede entregarse STOP por una red cortada.
8. Ir a ajustes Wi-Fi del teléfono y volver. La app detiene el movimiento antes de
   suspender la conexión. Al volver exige nuevo READY. Si DHCP cambió la IP, editar
   la URL real; con firmware antiguo no se adivina la nueva identidad/dirección.
9. Editar URL varias veces y cancelar el diálogo: no debe haber pantalla roja,
   `_dependents.isEmpty` ni TextEditingController dispuesto prematuramente.
10. Buscar ESP32/Búsqueda de dispositivos recopila solo V2; el firmware antiguo
    puede no responder. Si UDP está bloqueado, la URL manual sigue funcionando.

## Prueba futura con router y firmware V2

1. Implementar [esp32-v2.md](esp32-v2.md), incluidos vectores, watchdog, ping/pong,
   almacenamiento de K y bloqueo exclusivo en Arduino. Provisionar por USB una
   identidad y clave aleatoria por equipo; no usar la clave pública de los tests.
2. Compilar `flutter build apk --debug --dart-define=BLANQUITA_MULTI_DEVICE=true`.
   Confirmar que laboratorio está deshabilitado incluso con preferencias antiguas.
3. Unir teléfono y ESP32 a la LAN. Buscar, esperar los 3 s completos y seleccionar
   explícitamente el cartesiano propio entre todos los candidatos.
4. Vincular introduciendo la credencial física. Comprobar estados Encontrado →
   Conectando → Identidad verificada → Autenticando → Autorizado. Los pasos
   intermedios pueden ser muy breves. Solo al final se habilita control.
5. Sin UDP, guardar la URL manual y abrir Seleccionar dispositivo → Seleccionar por
   identidad y URL manual; introducir el ID físico/nombre y luego Vincular. La URL
   manual conserva la verificación de la misma identidad y credencial V2.
6. Renovar DHCP y pasar hotspot → router; la app intenta el enlace conocido, busca
   solo el deviceId vinculado, verifica de nuevo y guarda su nueva dirección.
   Otro ID nunca recibe comandos físicos. Dos IP con el mismo ID requieren resolución
   explícita mediante URL manual y prueba criptográfica.
7. Intentar usar un segundo teléfono simultáneo. El firmware debe negar READY
   autorizado al segundo cliente. Inyectar una trama repetida o firma incorrecta:
   debe parar el equipo e invalidarse la sesión. Desvincular elimina la clave local;
   para revocar un teléfono perdido rotar la clave físicamente en Arduino.

## Cobertura automatizada

| Caso solicitado | Evidencia |
| --- | --- |
| 1–2. URL manual antigua y READY | machine_controller_test; esp32_native_channel_test abre WebSocket TCP real en loopback |
| 3. Reconexión misma IP | machine_controller_test: fresh READY, sin reanudar movimiento |
| 4. DHCP | machine_controller_test; hotfix_connection_widget_test |
| 5–6. Varios ESP32 y selección correcta | esp32_v2_discovery_test: UDP real, ventana completa; machine_controller_test: filtro por ID |
| 7. Dispositivo diferente | rechazo de ID, clave, MAC falsa y downgrade READY |
| 8. Timeout handshake | firmware antiguo y V2 sin READY autorizado |
| 9. UDP cancelado | cancel/dispose durante bind; respuesta tardía ignorada por generación |
| 10. Movimiento sin enlace válido | antes de READY, sin clave, antes de persistir, tras fallo y cancelación |
| 11. STOP al perder enlace | intento x; heartbeat cancelado; sesión V2 usa x firmado |
| 12. Persistencia | identidad y nombre tras DHCP; adapter secure storage con mock; controlador recreado |
| 13. URL sin crash | 12 pruebas hotfix, incluido laboratorio explícito; MaterialApp/Navigator/providers estables |
| 14. Hotspot/router | recuperación en tres LAN simuladas con misma identidad; prueba física pendiente |

Pruebas extra: replay, errores de credencial/almacenamiento, cancelación de
vinculación, identidades duplicadas y build con laboratorio prohibido. Los mocks
de secure storage comprueban el adapter; cifrado/Keystore real requiere Android.

```powershell
flutter analyze
flutter test
flutter test --dart-define=BLANQUITA_MULTI_DEVICE=true test/core/network/esp32_deployment_test.dart
flutter build apk --debug
```

Resultados en este workspace: `flutter analyze` sin observaciones; `flutter test`
con **117 pruebas correctas**; variante `BLANQUITA_MULTI_DEVICE=true` con sus dos
pruebas correctas; `flutter build apk --debug` compilado. APK en
`build/app/outputs/flutter-apk/app-debug.apk`. `flutter devices` solo detectó
Windows, Chrome y Edge: no había Android conectado para ejecutar pruebas físicas.

## Archivos de la entrega

- `lib/core/models/esp32_device.dart`: identidad pública y fases de conexión.
- `lib/core/network/esp32_discovery_service.dart`, `discovery_collector_io.dart`,
  `discovery_collector_stub.dart`: contrato V2 y ventana UDP cancelable.
- `lib/core/protocol/esp32_session.dart`: desafío/respuesta y sesión firmada.
- `lib/core/storage/esp32_credential_store.dart`, `settings_repository.dart`:
  secreto separado de preferencias públicas.
- `lib/core/websocket/machine_controller.dart`, `esp32_channel*.dart`:
  conexión, reconexión por identidad, laboratorio, STOP y ping/pong nativo.
- `lib/features/settings/controller/{app_settings,settings_controller}.dart`,
  `presentation/{settings_screen,esp32_identity_panel}.dart`: selección/vinculación,
  modo explícito, diagnósticos y diálogos que esperan terminar de cerrarse.
- `lib/features/diagnostics/presentation/diagnostics_screen.dart`: autenticación/ID.
- `android/app/src/main/AndroidManifest.xml`, `res/xml/network_security_config.xml`:
  respaldo de credenciales deshabilitado y red local sin SSID fijo.
- `pubspec.yaml`, `pubspec.lock` y registradores generados Linux/macOS/Windows:
  dependencias de crypto y almacenamiento seguro.
- `test/core/{network,protocol,storage,websocket}`, `test/support/esp32_test_peer.dart`,
  pruebas hotfix/widget y ajuste explícito de laboratorio en el test de independencia
  Vision/Machine. No se modificó implementación de visión.
- README, contrato V2, vectores .NET y esta guía. Documentos históricos de discovery
  y hotfix señalan el contrato que los sustituye.

No se hizo commit ni push. El resultado no acredita autenticación V2 física:
depende de que Arduino implemente y valide exactamente el mismo protocolo.

La inspección inicial encontró `fix/autoconnect-stability`. Al cierre se detectó
un checkout externo a `feat/furuxqfurula`; ambas ramas apuntaban a `4079a97`.
Se conservó la rama activa externa y los cambios sin commit en el workspace.
