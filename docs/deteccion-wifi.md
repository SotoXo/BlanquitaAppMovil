# Wi-Fi del teléfono — detección y calidad observadas

## Cómo usarlo

Conectar el teléfono a la red desde Ajustes de Android. Abrir BLANQUITA Víctor y
revisar **Wi-Fi del teléfono** antes de configurar los WebSockets del ESP32 y la
laptop. El panel aparece en Inicio, Ajustes y Diagnósticos; permite actualizar la
lectura. En Diagnósticos, **COPIAR BITÁCORA** incluye la instantánea Wi-Fi en `APP`
y mantiene el control y visión en sus secciones independientes.

`CARTESIANO` sigue siendo una referencia de red esperada. La app detecta si existe
conexión Wi-Fi, pero no lee su SSID; por tanto no afirma estar conectada a una red
de nombre CARTESIANO. Las IP de ESP32/laptop deben obtenerse de los dispositivos o
del router y configurarse por separado.

## Qué significa cada dato

| Dato | Qué permite observar | Qué no demuestra |
| --- | --- | --- |
| Wi-Fi habilitado | Radio habilitada según Android | Asociación a una red o acceso a equipos |
| Conexión Wi-Fi | Enlace Wi-Fi del teléfono observado | Identidad del punto de acceso o acceso a ESP32/laptop |
| IPv4 local | Dirección del teléfono en esa conexión | IP del ESP32/laptop, ni comunicación entre clientes |
| Señal / RSSI en dBm | Potencia recibida y orientación de calidad | Fiabilidad de comandos, pérdida de paquetes o latencia al robot |
| Velocidad de enlace en Mbps | Velocidad del enlace informada por Android | Caudal real transferido o velocidad de Internet |
| Ruta predeterminada Wi-Fi | Android tiene Wi-Fi como ruta predeterminada | Ruta efectiva de cualquier destino concreto |
| Internet validado | Android validó acceso a Internet en esa red | Acceso a ESP32/laptop o requisito para usar BLANQUITA |
| Tiempo conectado observado | Continuidad registrada mientras la app observa | Tiempo previo a abrir la app o estabilidad futura |
| Cortes / cambios observados | Transiciones observadas en la ventana actual | Historial fuera del primer plano o causa de un cambio |

El RSSI y la velocidad de enlace proceden de `WifiInfo` cuando Android los facilita.
Los valores desconocidos se presentan como no disponibles, sin inventarlos. Sus
unidades están definidas en la [referencia oficial de WifiInfo](https://developer.android.com/reference/android/net/wifi/WifiInfo).

“Sin cortes observados” significa que no se registraron desconexiones durante la
ventana de observación de esta sesión en primer plano. La app no realiza un test de
velocidad, ping a Internet ni mide throughput. La señal puede fluctuar y la red
puede fallar después: la etiqueta de estabilidad describe evidencia ya observada.
Una pausa de la app no cuenta como una desconexión Wi-Fi ni aporta evidencia de lo
que ocurrió en segundo plano; al volver comienza una nueva ventana de observación.
El controlador reinicia tiempo conectado y contadores al iniciar esa ventana.
Primero muestra “Observando enlace”; tras al menos 10 segundos conectada, sin cortes
ni cambios observados, puede mostrar “Sin cortes observados”. Las consultas
periódicas ocurren cada 3 segundos, además de los cambios informados por Android;
un intervalo no observado no equivale a una garantía de continuidad.

## Wi-Fi sin Internet y selección de ruta

Una LAN sin Internet puede servir para BLANQUITA. La ausencia de Internet validado
no invalida por sí sola la comunicación local. Android separa la conexión de red
de la validación de acceso general a Internet mediante
[NetworkCapabilities](https://developer.android.com/reference/android/net/NetworkCapabilities).

Si el teléfono está conectado a Wi-Fi pero Android usa otra ruta predeterminada,
por ejemplo datos móviles, el panel advierte esa diferencia. La app no fuerza
binding de sus WebSockets o del proceso a Wi-Fi ni cambia las redes del sistema. Consultar el fallo del WebSocket
antes de decidir si el problema es de dirección, puerto, ruta o servidor.

La conexión local sólo queda confirmada por el canal correspondiente: transporte
abierto y `READY` para ESP32; transporte abierto y `vision.ready` para laptop. Un
RSSI fuerte no detecta aislamiento de clientes del router/hotspot.

Diagnósticos permite **Verificar puerto por Wi-Fi** en cada endpoint válido. Esta
prueba adicional usa un socket TCP de la conexión Wi-Fi sólo para el host/puerto
configurado, sin enviar datos de aplicación, hacer barrido ni cambiar la ruta
global del proceso o del WebSocket. El resultado entra en NETWORK de la bitácora;
TCP accesible no sustituye los mensajes `READY` o `vision.ready`.
La [prueba real desde el teléfono](prueba-conexiones-reales.md) registró Wi-Fi
conectado, pero TCP dirigido por Wi-Fi no alcanzó ninguno de los servidores.

## Implementación y permisos

Android aporta instantáneas y cambios de conectividad mediante
`ConnectivityManager`, propiedades de enlace e información Wi-Fi. Flutter mantiene
un `WifiNetworkController` independiente de `MachineController` y `VisionController`.
No se altera el transporte WebSocket, la reconexión ni la seguridad física. En
plataformas no soportadas se informa la limitación; no se simula una detección.

Se añaden únicamente `ACCESS_NETWORK_STATE` y `ACCESS_WIFI_STATE` como permisos
normales. Se mantienen `INTERNET`, configuración cleartext y target SDK 36 de la
entrega. No se añaden ubicación, Nearby Wi-Fi, escaneo de SSID, BSSID, contraseñas ni
conexión automática al hotspot. Las reglas futuras de permiso LAN al elevar target
SDK están descritas en [arquitectura de conexión](network-architecture.md).

## Comprobación y límites de evidencia

1. Con el teléfono en Wi-Fi, abrir la app y comparar su IPv4 y conexión con Android.
2. Actualizar el panel: verificar timestamp y que una lectura ausente no se presenta
   como valor real de RSSI o velocidad.
3. Durante una prueba sin movimientos, apagar y reactivar Wi-Fi desde Android;
   verificar las transiciones, el corte observado y la nueva conexión.
4. Cambiar de red Wi-Fi y comprobar cambios observados, IP y ruta; no esperar que
   la app obtenga ni muestre el nombre SSID.
5. Pasar a segundo plano y regresar: comprobar una nueva ventana de observación
   sin contar la pausa como un fallo Wi-Fi.
6. Probar una LAN sin Internet: comprobar que la advertencia no equivale a un bloqueo
   de los WebSockets ni sustituye la prueba READY del dispositivo.
7. Copiar la bitácora: revisar métricas Wi-Fi en APP y dos endpoints separados.

Las 86 pruebas y capturas de la entrega anterior corresponden a la corrección de
conexiones/formularios; no validan esta ampliación posterior. Registrar resultados
actuales de lectura Wi-Fi, analyze, pruebas y APK al completar la implementación.
El funcionamiento completo con router/hotspot, ESP32 y laptop reales no se ha
validado y no se puede deducir sólo de las métricas Wi-Fi del teléfono.

En la comprobación posterior la lectura Wi-Fi sí pasó en el teléfono. Falló el
alcance a ESP32/laptop por WebSocket y por TCP dirigido a Wi-Fi. La confirmación
de protocolo y funcionamiento físico siguen pendientes; consultar el informe de
prueba real para datos y errores, sin interpretar el fallo como problema exclusivo
de la ruta predeterminada.
