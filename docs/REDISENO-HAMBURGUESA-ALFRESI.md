# BLANQUITA ALFRESI — refinamiento visual y lluvia de hamburguesas

Fecha: 20 de octubre de 2026. Rama: `feat/victor-hamburger-ui`.

## Base y alcance

Base funcional de `feature/victor`: `495b6ae`. Checkpoint previo al refinamiento: `dd946db` (`chore: checkpoint antes de refinamiento visual alfresi`). El stash anterior de `fix/autoconnect-stability` permanece preservado y no se aplicó sobre esta rama.

Se cambió presentación Flutter, recursos visuales y pruebas del frontend. No se modificaron los controladores, modelos operativos, servicios, protocolo, reconexión, almacenamiento funcional, lifecycle operativo ni código Kotlin. Los callbacks de movimiento, pinza, velocidad, secuencia, STOP y emergencia continúan llamando las acciones públicas existentes con las mismas condiciones de habilitación.

La revisión previa y la comparación de las 13 pantallas, con correcciones posteriores a abrir cada captura, están en [comparacion.md](evidencias/ui-final/comparacion.md).

## Identidad y respaldo Android

| Variante | Nombre | Application ID |
| --- | --- | --- |
| Respaldo | BLANQUITA Víctor | `com.example.blanquita.victor` |
| Interfaz nueva | BLANQUITA ALFRESI | `com.example.blanquita.alfresi` |

Se mantiene el ID independiente creado en el checkpoint y se actualiza solo el icono vectorial del launcher a la marca hamburguesa. La actividad y el namespace nativos conservan sus valores. Instalar la variante visual no sustituye el paquete Víctor ni comparte sus preferencias por Android.

APK: `build/app/outputs/flutter-apk/blanquita-alfresi-debug.apk`.

## Pantallas

| Pantalla | Resultado |
| --- | --- |
| Splash | Marca, frutilla grande, título, progreso visual de arranque y fondo cálido. No espera ni posterga conexiones. Reduce Motion omite la animación introductoria. |
| Inicio | Header compacto, burbuja crema, conexiones primero y visualizador cartesiano existente; estado al pie, sensores y actividad real. |
| Dispositivos | Equipos configurados, endpoints seguros y estado confirmado. Diagrama estático con aviso de que esta base no expone discovery. |
| Vinculación | Timeline Conectar → Confirmar READY, fase pública y detalles de conexión. |
| Control | Pad radial con direcciones, STOP rojo central, detención independiente, motivo de bloqueo, pinza y velocidad originales. Al 200 % se utiliza la distribución flexible. |
| Visión | Conexión, placeholder explícito sin streaming, sistema, último reporte y alertas. Acciones existentes disponibles en desplegable. |
| Diagnósticos | Header único, Conexiones/Sistema/Logs y timeline de eventos. Copiar bitácora y limpiar conservan sus callbacks. |
| Ajustes | Filas con icono/valor, selector rápido y hojas de detalle enfocadas en texto, efectos o asistente. Conexiones y ajustes operativos conservados. |
| Tema visual | Tres previews locales, selección temporal y Aplicar tema. |
| Modales/bloqueo | ALFRESI según emoción, icono semántico, mensaje real y acciones existentes; panel rojo, verde o azul según estado. |

Hamburguesa utiliza cinco destinos: Inicio, Dispositivos, Control, Visión y Ajustes. Se conserva el `PageController`, los cuatro índices previos y sus páginas. Dispositivos se agrega como vista de presentación. Original conserva su navegación y composición de Inicio anteriores.

## Tokens y componentes

`lib/app/design/blanquita_tokens.dart` centraliza espaciado (4/8/12/16/24), radios (12/18/22/28), tipografía y movimiento. `BlanquitaColors` es un `ThemeExtension` interpolable.

| Token | Valor base |
| --- | --- |
| backgroundDeep / background | #17100B / #21150D |
| surface / surfaceSoft / surfaceRaised | #321F10 / #3A2515 / #4A2A12 |
| brownStrong | #6D360F |
| cream / creamMuted | #F6EBD3 / #AAA59A |
| cheese / cheddar | #F1B822 / #CA6730 |
| lettuce / success | #7AC227 / #29D24A |
| ketchup / danger | #DD1415 / #FF2B25 |
| info | #43A7D8 |

Amarillo para selección y acción, verde para confirmación, atención cálida para espera y rojo para seguridad/STOP. El modal esperando usa azul informativo. Las tarjetas son opacas, con borde cálido y sombra opcional; no tienen blur por tarjeta.

Componentes compartidos creados o consolidados:

- `BlanquitaScaffold`, `BlanquitaHeader`, `PageHeader`.
- `BlanquitaCard`, `GlassSurface`/`GlassPanel` con ramas de tema.
- `BlanquitaButton`, `GlassButton`, estilos Filled/Outlined y botones de movimiento existentes.
- `BlanquitaStatus`, `BlanquitaDeviceCard`, `BlanquitaSection`, `BlanquitaSegmentedControl`.
- `BlanquitaBottomNavigation`, `BlanquitaTimeline`, `BlanquitaModal`, `BlanquitaLockState`, `BlanquitaErrorState`.
- `BlanquitaBrand`/`BurgerMarkPainter`, `AppBackground`/pintor de lluvia.
- `AlfresiAvatar`, `AlfresiBubble`, `AlfresiButton`, `AlfresiPanel`.
- `BlanquitaSplash`, `StartupPresentation`, `DevicesScreen`, `DeviceRadarPainter`, `BindingScreen`, `VisionOverview`, `ThemeVisualScreen`, `PersonalizationPanel`.

## Fondo y movimiento

El fondo local `assets/alfresi/fondo_hamburguesa.png` coloca hamburguesas iluminadas en las esquinas y reserva el centro oscuro para lectura. Una capa `CustomPainter` dibuja 16 hamburguesas pequeñas con caída y oscilación moderadas. No usa emojis, dependencias nuevas, timers ni búsquedas reales.

La lluvia se ejecuta durante 10 segundos al entrar/cambiar de pantalla o tema y después se asienta para ahorrar batería. El mismo elemento hijo permanece montado. `RepaintBoundary` aísla el repintado decorativo y el pintor no requiere capas offscreen por partícula. El fondo y la lluvia no capturan gestos ni aparecen en la lectura semántica.

Reduce Motion, la accesibilidad del sistema y modo rendimiento detienen el movimiento. El fondo ilustrado sigue visible, sin volver a un fondo plano. Original conserva su fondo industrial previo.

Las microinteracciones utilizan 190 ms, modales 220 ms y cambio de tema 400 ms con `easeOutCubic`. El tema interpola superficies mediante `ThemeData`/`ThemeExtension`; `VisualTransition` añade fade parcial y blur ligero desactivable sobre el mismo hijo. No reinicia providers, rutas ni conexiones. El splash es solo de arranque, nunca se utiliza al cambiar tema.

## Personalización

- Original / Hamburguesa / Personalizado, independiente de Oscuro / Claro / Sistema.
- Acento personalizado Queso / Sésamo / Cian, conservando colores de seguridad.
- Outfit local / Sistema; texto Pequeño / Normal / Grande; interfaz Compacta / Normal / Grande.
- Animaciones, difuminado de transición, sombras y modo rendimiento.
- ALFRESI: asistente, consejos, avisos, detalles técnicos y efectos.

Se consumen las preferencias persistidas existentes del checkpoint. El tamaño se combina con `MediaQuery.textScaler`; no se limita la escala del sistema. Las acciones importantes conservan 48 px de área táctil y los botones bloqueados muestran candado además de color.

## ALFRESI y recursos

Se usa la **frutilla exacta enviada por el usuario**: `assets/alfresi/referencia_frutilla.png` conserva el archivo original sin alteración. `AlfresiAvatar` selecciona viewports de su atlas para normal, feliz, pensando, atención y error, y el personaje grande del splash. No se sustituyó por una nueva frutilla ni por un robot. Los recursos del robot del checkpoint permanecen como archivos históricos sin usarse en el avatar actual.

Tamaños centralizados: 24, 32, 48, 64, 112 y 220 px. Modales usan una expresión de 96 px. Las burbujas tienen fondo crema, texto marrón y cola pequeña. El header utiliza 48 px para el acceso al panel.

El contexto y las reglas de ALFRESI permanecen sin cambios: leen estados públicos de Machine/Vision, disponibilidad manual, transporte, fase y sección. Explican conexiones independientes, espera READY, error real, final de carrera, bloqueo manual, secuencia y estados desconocidos. El panel ofrece Resumen, Diagnóstico, Ayuda y evidencia “¿Por qué?”. Solo puede navegar a Diagnósticos; no ejecuta movimiento, pinza, secuencia, STOP o emergencia. No hay API, LLM ni dependencia de Internet durante el uso.

El fondo de hamburguesas sí es un recurso nuevo generado para el proyecto. No se utilizó una imagen generativa como captura de la aplicación. Las búsquedas visuales se usaron como inspiración; el recurso final se almacena localmente.

## Verificación y capturas

Resultados finales: [validacion/RESULTADOS.md](evidencias/ui-final/validacion/RESULTADOS.md).

Los 116 tests anteriores se conservan sin modificar. Se añadieron 15 goldens, siete escenarios responsive y pruebas de movimiento reducido y de aplicación explícita del tema conservando ruta, instancias, conexiones y logs. La prueba previa con canales WebSocket de test sigue verificando que cambiar de tema no recrea los controladores reales.

Las capturas/goldens se generan con Flutter, fuentes locales y escenarios de prueba deterministas a 390×844, exportados al doble de resolución. Los dominios `.test`, conexiones y logs de ejemplo se limitan a tests, no se inyectan en la app real. También se verifica 360/390/412, tablet y landscape, con texto de sistema al 200 % y opciones de texto/densidad Grande.

Para regenerar capturas y goldens tras revisar cambios visuales:

```powershell
flutter test test/refinement_goldens_test.dart --dart-define=CAPTURAR_REFINAMIENTO=true --update-goldens
```

Para verificar sin reescribir las expectativas:

```powershell
flutter test
```

## Limitaciones conocidas

- No es pixel-perfect: el robot real se representa como cartesiano y el montaje de referencia muestra un brazo articulado.
- Esta base no ofrece discovery ni fases públicas HMAC/V2. Se muestran los datos existentes, con un radar estático claramente explicado.
- No hay streaming; FPS, latencia y reportes ausentes siguen como “—” o “Sin datos”. No hay porcentaje de velocidad absoluto.
- La frutilla mantiene la resolución y el fondo del montaje original. Los recortes pequeños no equivalen a assets transparentes independientes en alta resolución.
- Las capturas de prueba acreditan render y composición; la instalación en teléfono acredita el frontend Android. No se realizaron movimientos del robot ni se usó hardware para rellenar estados.
