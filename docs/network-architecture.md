# BLANQUITA — arquitectura de conexión y diagnóstico

## Red y responsabilidades

Móvil, ESP32 y laptop pertenecen a una LAN común creada por un router, hotspot u
otro punto de acceso. `CARTESIANO` es un nombre de red esperado, no una detección:
la app no consulta SSID, no busca redes Wi-Fi ni almacena su contraseña.
La conexión Wi-Fi del teléfono sí se observa mediante Android, junto con su IPv4,
señal y continuidad en primer plano. Esa observación no identifica el nombre
CARTESIANO ni descubre al ESP32 o a la laptop.

```text
                    RED LOCAL
                  Hotspot / router
                         │
            ┌────────────┼────────────┐
            │            │            │
          Laptop       Móvil         ESP32
       percepción   supervisión   ejecución física
            └──── WS ────┤──── WS ────┘

Móvil → ws://IP_ESP32:81/    MachineController
Móvil → ws://IP_LAPTOP:8765/ VisionController
```

El punto de acceso proporciona IP y conectividad. Cada dispositivo servidor debe
estar encendido y escuchando en su puerto. La laptop procesa cámara, visión,
calibración y reportes. El ESP32 ejecuta motores, pinza, sensores y seguridad.
El móvil supervisa ambos canales. Visión no invoca control físico.
No se usa descubrimiento UDP, broadcast ni escaneo de redes o SSID. Las IP deben
ser conocidas y configuradas; una reserva DHCP ayuda a mantenerlas estables.

### Datos aportados por el usuario y comprobación pendiente

El log serial del ESP32 aportado indica `192.168.137.209`, puerto WebSocket 81,
`ROLE:SENSORES`, mensajes de plato/final/snapshot y “SISTEMA LISTO”. La URL candidata
es `ws://192.168.137.209:81/`. Esa salida confirma lo anunciado por el firmware en
serial; no prueba que el móvil alcance el socket ni que ese endpoint envíe `READY`
por WebSocket. “SISTEMA LISTO” en serial no equivale al handshake `READY` esperado
por el cliente. La función de control físico debe contrastarse con el rol del
firmware antes de atribuir capacidades a este equipo.

El log del servidor de visión aportado posteriormente indica escucha WebSocket en
`0.0.0.0:8765`. La URL del móvil requiere la IP LAN de esa laptop:
`ws://<IP-LAN-laptop>:8765/`. `0.0.0.0` expresa escucha en interfaces del servidor,
no una dirección remota válida para configurar el cliente. El puerto 8765 de este
log reemplaza el 6580 indicado anteriormente. El anuncio UDP del servidor no se
usa para descubrir ni conectar: permanece el WebSocket configurado manualmente.

Estos datos proceden de los logs entregados por el usuario. Después se aportó la
IP de laptop `192.168.137.27`. La prueba real desde el teléfono `192.168.137.201`
registró Wi-Fi conectado, RSSI -48 dBm y 573 Mbps de enlace, pero no abrió ninguno
de los dos WebSockets: timeout 5000 ms en ESP32 y 8000 ms en visión. La comprobación
TCP dirigida específicamente por Wi-Fi falló también en ambos con
`EHOSTUNREACH (No route to host)`. No hubo RX/TX de aplicación ni confirmación de
protocolo. Ver [prueba real y errores conservados](prueba-conexiones-reales.md).
La repetición de 14:25:08–14:25:45, tras confirmar el usuario que el ESP32 estaba
encendido, mantuvo los timeouts WebSocket. TCP dirigido por Wi-Fi dio
`HOST_UNREACHABLE` / `EHOSTUNREACH` para ESP32 (2326 ms) y `CONNECT_TIMEOUT` para
laptop (3008 ms). Wi-Fi permaneció observado durante 36 s sin cortes; no hubo
RX/TX de aplicación. Estas mediciones describen un fallo de alcance, sin identificar
su causa. Falta verificar `READY`/`vision.ready` después de resolverlo. No se deduce
compatibilidad del firmware sólo por las salidas de inicio.
ICMP por `wlan0` al ESP32 tampoco recibió respuesta (2 paquetes, 2 errores) y
su entrada vecina fue `FAILED`. Falta el serial actual posterior al encendido para
contrastar red e IP; los resultados no prueban una causa única del fallo LAN.

## Endpoints y flujo

Antes de las tarjetas de endpoints, Ajustes y Diagnósticos muestran **Wi-Fi del
teléfono**. Esta lectura es informativa e independiente: no cambia URLs,
reconexiones ni la validación READY. El bloqueo físico sigue dependiendo del canal
ESP32 y sus medidas de seguridad. La app no conecta a un hotspot por sí sola ni
fuerza los WebSockets a una interfaz de red. Si Android usa otra ruta predeterminada
se muestra una advertencia, sin atribuir una causa definitiva de fallo.
Ver [detección Wi-Fi y límites de las métricas](deteccion-wifi.md).

Cada tarjeta en Diagnósticos añade **Verificar puerto por Wi-Fi**: conexión TCP
al host/puerto configurado usando un socket de esa red, sin modificar la ruta
global del proceso. No abre un protocolo WebSocket ni envía comandos físicos.
Un resultado positivo no habilita control o visión; siguen requiriendo su
handshake. Resultado y errores se registran como eventos NETWORK en la bitácora.

| Canal | Clave persistente | Validación de protocolo | Reconexión |
| --- | --- | --- | --- |
| ESP32 | `connection.websocket_url` | `READY` | 2, 4, 8, 15 s, hasta 15 s |
| Laptop | `vision.websocket_url` | `vision.ready` | 1, 2, 4, 8, 16 s, hasta 30 s |

Ambas URLs empiezan vacías. Los ejemplos de IP no son direcciones predeterminadas.
Cambiar un endpoint reemplaza únicamente la sesión de ese canal. La desconexión
manual cancela sus reintentos y los intentos obsoletos no pueden reactivar sesiones.

```text
desconectado → validar endpoint → abrir transporte
→ WebSocket abierto → esperar confirmación → protocolo validado
```

La apertura y la confirmación tienen fases independientes en Diagnósticos. Ningún
comando de movimiento se autoriza sin `READY`. **PROBAR CONEXIÓN** reutiliza el
flujo del canal y no envía movimientos, pinza, secuencia ni cambios de velocidad.
Visión puede enviar `vision.ping` como parte de su protocolo.

Cuando falla visión, el ESP32 y sus controles siguen disponibles si su sesión está
validada. Cuando falla ESP32, los controles físicos quedan bloqueados y visión
puede continuar. Cada controlador gestiona sus temporizadores, sesiones, errores
y reconexiones. El lifecycle detiene el movimiento y suspende intentos/reintentos
de control al salir del primer plano; una sesión ESP32 ya validada puede permanecer
abierta, con controles físicos bloqueados en segundo plano. Visión cierra su sesión.
El regreso respeta el deseo de conexión y sus ajustes.
Editar explícitamente cualquiera de las URLs solicita conectar al nuevo endpoint aunque
la reconexión automática esté desactivada; si la app está en segundo plano, ese
intento se realiza al volver. Una desconexión manual cancela esa solicitud.

## Bitácora y lectura de errores

Diagnósticos presenta **ESP32 · CONTROL** y **Laptop · VISIÓN**, con estado,
endpoint, host/puerto, fase, transporte abierto/cerrado, confirmación del protocolo,
últimos RX/TX, recepción local, reintentos y último error. Los datos de sensores o
reportes anteriores pueden permanecer como histórico; no prueban una conexión actual.

`ConnectionLog` reúne eventos de sistema, control, visión y red en memoria, con
fecha/hora, nivel, explicación humana, detalle técnico, código, endpoint, fase e
intento. Cada entrada tiene texto de nivel además del color. **Detalles técnicos**
se despliega para consultar el error original. La salida debug utiliza el prefijo
`[BLANQUITA][CANAL]`. No se guardan contraseñas como historial.
La bitácora central conserva hasta 240 entradas. Los eventos repetidos de visión
(ping, heartbeat y reporte) se muestrean cada 10 segundos por tipo y exponen su
contador de sesión; los mensajes siguen procesándose en su frecuencia original.
Errores y transiciones de conexión se registran individualmente.

**COPIAR BITÁCORA** exporta un texto con `APP`, `CONTROL`, `VISION` y `EVENTS`.
`APP` incluye la instantánea Wi-Fi disponible y la ventana de observación; la
dirección del teléfono no se mezcla con los endpoints de los servidores.
Copiar conserva el estado actual aunque no haya eventos. **LIMPIAR** borra el
historial de conexiones en memoria; no desconecta equipos ni cambia los endpoints.
Después de reproducir un fallo, copiar el texto antes de cerrar la app o limpiar.

| Evidencia | Interpretación y siguiente comprobación |
| --- | --- |
| Endpoint vacío/inválido | Editar la URL: esquema ws/wss, host y puerto correctos. |
| `CONNECT_TIMEOUT` | El transporte no abrió a tiempo. Posibles causas: dirección, equipo apagado, ruta, filtro o aislamiento. No identifica cuál. |
| `CONNECTION_REFUSED` | El destino rechazó la conexión. Revisar dirección, puerto y servidor escuchando; no identifica al hardware. |
| `HOST_UNREACHABLE` | El sistema reportó un destino no alcanzable. Revisar red/ruta y aislamiento de clientes. |
| Handshake fallido | Hubo fallo al negociar WebSocket; revisar servicio, ruta y protocolo del servidor. |
| `READY_TIMEOUT` | WebSocket abrió, pero faltó la confirmación esperada. Revisar firmware/protocolo del canal. |
| `REMOTE_CLOSED` | El extremo remoto cerró la sesión. Revisar cierre y logs del servidor. |
| Heartbeat de visión vencido | El socket puede seguir abierto; la telemetría no se considera vigente. |
| Reporte/JSON inválido | El cliente registra el rechazo y conserva el último reporte válido. |

Si los dos canales registran fallos de transporte, la UI propone revisar la LAN
como **posible causa**. Si uno está validado, muestra qué canal aún debe revisarse.
La accesibilidad de la laptop no demuestra la ruta hacia el ESP32. Ningún timeout
por sí solo distingue IP equivocada, puerto equivocado, equipo apagado, distinta
red, firewall o aislamiento del router/hotspot.

## Seguridad física conservada

No cambia el contrato `a/d/w/s`, `x`, `k` cada 200 ms durante movimiento,
`q/e`, `j`, `z` y `+/-`. STOP al soltar, emergencia, bloqueo por final de carrera
y control seguro del lifecycle pertenecen al canal ESP32. Los reportes de visión
son informativos y no autorizan movimiento automáticamente. `READY` valida el
protocolo esperado; no autentica criptográficamente al dispositivo.

## Android: SDK inspeccionado

`android/app/build.gradle.kts` usa `flutter.compileSdkVersion` y
`flutter.targetSdkVersion`. `android/local.properties` apunta a `C:\dev\flutter`.
En el SDK local inspeccionado el 6 de octubre de 2026,
`packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` define ambos
valores en **36**. No se elevó el target para esta corrección.

El manifiesto mantiene `INTERNET`, `usesCleartextTraffic=true` y
`network_security_config` para WebSocket LAN sin TLS. Para target 36 o inferior,
Android concede LAN con `INTERNET`; no se declara `ACCESS_LOCAL_NETWORK`.
Si en una migración se sube a target 37 o superior, habrá que declarar y pedir ese
permiso en runtime antes de abrir ambos canales y manejar denegación/revocación.
Android 16 ofrece restricciones LAN como opt-in de desarrollo. Estos requisitos
se verificaron en la [documentación oficial de acceso LAN de Android](https://developer.android.com/privacy-and-security/local-network-permission).

No se añaden permisos de ubicación ni Nearby Wi-Fi para conectar a URLs conocidas.
Un fallo de red no se corrige añadiendo permisos que no corresponden al SDK real.
La ampliación solicitada de lectura Wi-Fi añade únicamente los permisos normales
`ACCESS_NETWORK_STATE` y `ACCESS_WIFI_STATE`. Permiten observar conectividad y
estado del enlace sin explorar redes o consultar SSID, BSSID o contraseñas.

## Comprobación con equipos reales

1. Conectar móvil, ESP32 y laptop a la misma LAN. Obtener las IP actuales desde
   cada servidor o router. Confirmar que el punto de acceso permite clientes entre sí.
2. Configurar control y visión por separado. Abrir Diagnósticos: verificar
   transporte y confirmación `READY`/`vision.ready` en cada tarjeta y evento.
3. Desconectar el servidor de laptop: comprobar que control manual y STOP siguen
   funcionando. Restaurarlo y comprobar la reconexión exclusiva de visión.
4. Desconectar ESP32: comprobar el bloqueo físico y que los reportes de laptop
   siguen llegando. Restaurar ESP32 y esperar `READY` antes del control.
5. Probar una dirección/puerto que no responda: comprobar mensaje humano, código,
   fase y detalle técnico. Restaurar la URL correcta después de la prueba.
6. Probar con un servidor que abra WebSocket pero no confirme protocolo: comprobar
   que transporte abierto no se convierte en control disponible/visión lista.
7. Pausar y volver a la app: comprobar STOP, cierre seguro y reconexiones según
   ajustes. Desconectar manualmente y comprobar que no se reabre por un timer viejo.
8. Repetir edición/cancelación de URL, navegación y copia de bitácora en el móvil;
   comprobar ausencia del error de árbol Flutter `_dependents.isEmpty`.
9. Copiar la bitácora con un fallo reproducido. Revisar host/puerto y timestamps,
   y pegar el texto para diagnóstico sin necesitar `adb logcat`.

El repositorio no contiene el firmware `.ino` ni el servidor de laptop. Las pruebas
automatizadas de Flutter/loopback verifican el cliente, no la disponibilidad de esos
equipos ni las reglas del punto de acceso. No se debe declarar la prueba física
completa sin realizar esta lista con hardware real.

La assertion exacta `_dependents.isEmpty` de la captura no se reprodujo antes de la
corrección y no se atribuye una causa definitiva sólo a partir de la imagen.
El formulario corregido se probó en el teléfono original: escritura, validación,
corrección, guardar/cancelar repetidos y copia de bitácora, sin errores de widgets.
Se conservan pruebas de regresión y capturas. Esto verifica esos flujos, sin
garantizar que ningún otro escenario pueda producir una excepción.

## Verificación automatizada

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Resultados de la entrega previa a la ampliación Wi-Fi (6 de octubre de 2026):
86 pruebas automatizadas aprobadas, analyze sin incidencias y APK debug compilado.
La regresión de formulario
y copiar bitácora pasó en el teléfono, con canales simulados. El APK normal se
instaló como **BLANQUITA Víctor** (`com.example.blanquita.victor`), independiente
de la aplicación original. La comunicación con ESP32/laptop reales sigue pendiente.
La lista de archivos, capturas y resultados está en
[informe-correccion-conexiones.md](informe-correccion-conexiones.md).

La ampliación Wi-Fi requiere su ejecución actual de analyze, pruebas, compilación
y lectura en el dispositivo; esos 86 resultados anteriores no validan los cambios
posteriores. La conectividad física con ESP32 y laptop reales sigue pendiente.
