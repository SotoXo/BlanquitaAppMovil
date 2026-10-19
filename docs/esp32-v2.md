# ESP32: diagnóstico y contrato propuesto V2

Estado: cliente Flutter preparado; **firmware V2 pendiente**. No hay `.ino` ni
servidor Python en este checkout. READY antiguo no autentica. Este documento
define el protocolo que Arduino debe implementar antes de probar V2 físicamente.

## Diagnóstico previo a los cambios

- Rama `fix/autoconnect-stability`, remoto `SotoXo/BlanquitaAppMovil`, árbol limpio.
- URL manual sin IP predeterminada, WS 81, READY con timeout 5 s, reconexión
  exponencial, heartbeat k 200 ms y comandos originales ya implementados.
- Discovery antiguo aceptaba el primer HERE, sin identidad ni selección.
- READY habilitaba controles sin credencial. No existía exclusión entre clientes.
- El nombre CARTESIANO aparecía como red obligatoria; no se consultaba el SSID.
- La corrección de Ajustes ya espera `TransitionRoute.completed` antes de disponer
  el TextEditingController. Se conserva y se cubre con pruebas de regresión.
- Un enlace TCP silencioso podía permanecer aparentemente conectado; se añade
  vigilancia de transporte nativo sin cambiar el heartbeat físico k.

## Compatibilidad temporal

Modo laboratorio desactivado inicialmente. Activarlo explícitamente en Ajustes
permite probar **una URL manual** `ws://IP_REAL:81/` con READY antiguo. Se muestra
«Laboratorio: READY sin autenticación». No se selecciona automáticamente ningún
HERE antiguo. No activar laboratorio en una LAN con varios dispositivos.
Una compilación `--dart-define=BLANQUITA_MULTI_DEVICE=true` deshabilita este modo
aunque una preferencia antigua lo solicitara. Vincular un equipo V2 lo desactiva.
El firmware antiguo no puede garantizar identidad, exclusión de otros clientes
ni parada remota si se corta la red: su watchdog local es obligatorio.

## Discovery

UDP 4210; hasta tres solicitudes durante una ventana de 3 s:

```text
BLANQUITA_DISCOVER_V2
BLANQUITA_HERE_V2|deviceId|cartesian-controller|81
```

deviceId: ASCII `[A-Za-z0-9_-]{1,64}`, persistente tras reinicios y DHCP;
no derivar la identidad de la IP. La IP se toma únicamente del datagrama.
Se recopilan todos los candidatos hasta el final de la ventana, se deduplican
por identidad/dirección y se exige selección explícita inicial. Identidades
duplicadas con distintas direcciones no se resuelven tomando la primera.
Discovery no autentica. Tras vincular, solo se intenta el deviceId guardado.
Sin broadcast se conserva la URL manual para localizar el mismo equipo.

## Vinculación fuera de banda

Cada equipo se provisiona físicamente por USB con deviceId único y clave aleatoria
K de **32 bytes (64 caracteres hex minúscula)**. Entregar esos valores por QR o
medio físico al propietario; nunca transmitir K por UDP/WS ni usar PIN, MAC o SSID
como secreto. Arduino guarda K en almacenamiento protegido apropiado al chip.
Flutter introduce K con campo oculto, la guarda con flutter_secure_storage;
SharedPreferences solo guarda identidad pública/nombre/última dirección.
La vinculación se confirma después de demostrar K y recibir READY autorizado.
No hay alta remota abierta ni reemplazo automático de identidad. Desvincular
localmente elimina K; para revocar un teléfono perdido hay que rotar K por USB.

## Handshake WS V2 (JSON UTF-8, máximo 4096 bytes por trama)

Los siguientes nombres/campos son exactos. Cada conexión usa nuevos valores
aleatorios criptográficos: nonces de 32 bytes y sessionId de 16 bytes, en hex
minúscula. Timeout total 5 s. Nunca aceptar READY plano como downgrade de V2.

1. Flutter → `{"type":"hello.v2","deviceId":"…","clientNonce":"…"}`.
2. Arduino → `{"type":"challenge.v2","deviceId":"…","deviceType":"cartesian-controller","clientNonce":"…","serverNonce":"…","sessionId":"…","proof":"…"}`.
3. Flutter verifica deviceId/tipo/nonce y `proof`, entonces →
   `{"type":"auth.v2","sessionId":"…","proof":"…"}`.
4. Arduino verifica prueba, adquiere un bloqueo exclusivo de control de forma
   atómica, y → `{"type":"ready.v2","sessionId":"…","proof":"…"}`.
   Flutter solo habilita controles tras verificar esta última prueba.

Definición exacta: HMAC-SHA256(K, UTF8(texto)), salida hex minúscula 64 caracteres.
No firmar serializaciones JSON; concatenar campos ASCII con `|`:

```text
T = deviceId|cartesian-controller|clientNonce|serverNonce|sessionId
challenge.proof = HMAC(K, BLANQUITA_V2|server|T)
auth.proof      = HMAC(K, BLANQUITA_V2|client|T)
ready.proof     = HMAC(K, BLANQUITA_V2|ready|T)
SK             = HMAC(K, BLANQUITA_V2|session|T)  [32 bytes, no texto hex]
```

Errores durante handshake cierran el socket sin habilitar comandos. Nunca enviar
órdenes físicas a un candidato antes de verificar READY firmado.

## Comandos y eventos de sesión

Secuencias enteras independientes por dirección, empiezan en 1, aumentan exactamente
en uno, máximo 2147483647. Rechazar saltos, repetidos, overflow y otra sesión.

```json
{"type":"command.v2","sessionId":"…","seq":1,"command":"a","proof":"…"}
{"type":"event.v2","sessionId":"…","seq":1,"payload":"SENSOR:ESTADO:P=1,F=0","proof":"…"}
```

```text
command.proof = HMAC(SK, BLANQUITA_V2|command|sessionId|seq|command)
event.proof   = HMAC(SK, BLANQUITA_V2|event|sessionId|seq|payload)
```

seq usa decimal sin ceros iniciales. command conserva exactamente un carácter
`a d w s x k q e j z + -`. Arduino valida la envoltura y entrega ese carácter al
controlador actual. Eventos mantienen los mensajes/sensores originales dentro
de payload. Rechazar payload vacío, >1024 caracteres o que contenga `|`.
Comparar MAC sin salida anticipada. No registrar secretos, pruebas ni SK.
Tramas inválidas tras autorización invalidan la sesión, paran hardware y cierran.

Arduino mantiene **un solo propietario autenticado**; un segundo cliente no puede
robar el bloqueo y recibe cierre de conexión. Al desconectar, expirar watchdog,
recibir STOP/emergencia o violación de protocolo, detener y gestionar el bloqueo
según el estado seguro. Un cierre lo libera; STOP por sí solo no cede propiedad.
No aceptar comandos de texto plano en V2. El flag de laboratorio del teléfono no
autoriza a Arduino a ofrecer control antiguo en despliegues V2.

Heartbeat físico k cada 200 ms durante movimiento manual. Arduino debe parar ese movimiento
si no recibe k válido durante **600 ms**, independientemente de Wi-Fi/Flutter.
Secuencias y pinza también necesitan una política local segura al perder dueño.
Flutter intenta STOP antes de cerrar cuando aún hay transporte; no puede prometer
entrega de STOP por un enlace roto. WS ping/pong detecta enlaces silenciosos.
El servidor actual debe responder a ping estándar de WebSocket; probarlo con el
firmware real. No confundir ping/pong con el comando físico k. El navegador no
expone ping nativo; esta vigilancia se prepara para Android y plataformas nativas.

## Vectores para Arduino

[fixtures/esp32-v2-vectors.json](fixtures/esp32-v2-vectors.json) contiene vectores
deterministas generados con HMACSHA256 de .NET y comprobados desde Dart: clave de
prueba pública, nonces, pruebas de ambos lados, SK, primer comando y primer evento.
Arduino debe producir exactamente esos resultados. Los valores de prueba nunca
deben provisionarse en un equipo real; cada equipo necesita su propia clave aleatoria.

HMAC autentica e impide alteración/replay; WS plano no oculta telemetría ni evita
relay o denegación de servicio. Usar WSS y provisión adecuada si se requiere
confidencialidad. Requiere revisión conjunta Flutter/firmware antes de despliegue.

Referencias de implementación: [crypto/HMAC](https://pub.dev/documentation/crypto/latest/crypto/),
[almacenamiento seguro](https://pub.dev/packages/flutter_secure_storage),
[NVS Espressif](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/storage/nvs_encryption.html).
