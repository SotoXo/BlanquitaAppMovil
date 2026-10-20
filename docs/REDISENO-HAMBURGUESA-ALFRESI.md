# BLANQUITA ALFRESI — frontend, temas y personalización

Fecha: 20 de octubre de 2026.

## Rama y base funcional

Desarrollo en `feat/victor-hamburger-ui`, creada desde `feature/victor` después de `git fetch --all`, checkout y `git pull --ff-only origin feature/victor`. Base: `495b6ae`.

Antes del checkout había modificaciones locales en `analysis_options.yaml` y `pubspec.lock` de `fix/autoconnect-stability`. Se preservaron en el stash `preservado-antes-ui-victor-2026-10-20`; no se aplicaron sobre esta rama.

Los controladores `MachineController` y `VisionController`, modelos operativos, servicios de red, protocolo, firmware y código nativo de comunicación permanecen sin cambios. Las adiciones en almacenamiento y en el controlador de Ajustes corresponden exclusivamente a preferencias visuales. La interfaz llama las acciones públicas existentes.

## Aplicación independiente y respaldo

| Identidad Android | Aplicación anterior | Variante visual |
| --- | --- | --- |
| Nombre | BLANQUITA Víctor | **BLANQUITA ALFRESI** |
| Application ID | `com.example.blanquita.victor` | `com.example.blanquita.alfresi` |
| Icono | Anterior | Robot crema y dorado |

Los identificadores diferentes permiten instalar ambas aplicaciones. Las preferencias y direcciones de conexión de la nueva variante quedan separadas por Android. No se copian ni borran los datos del respaldo. El namespace y la actividad nativa siguen siendo los existentes.

APK de entrega: `../build/app/outputs/flutter-apk/blanquita-alfresi-debug.apk`.

## Pantallas modificadas

1. **Inicio:** jerarquía de estado general, robot cartesiano, conexiones, robot/sensores y actividad; aviso contextual de ALFRESI. Valores desconocidos permanecen como “Sin datos” o “—”.
2. **Control:** direcciones redondeadas con iconos; estado activo amarillo; candado, motivo concreto de bloqueo y diagnóstico; STOP central rojo; detención inmediata independiente y ancha; pinza y velocidad conservan sus acciones existentes. La velocidad sigue expresándose como incremento/decremento solicitado: el sistema no entrega una velocidad absoluta.
3. **Visión · laptop:** conexión independiente, sistema, último reporte y alertas. No se agregó video ni telemetría nueva.
4. **Ajustes:** selector de temas con paletas, personalización, efectos y ALFRESI; se conservan las conexiones y ajustes operativos anteriores.
5. **Diagnósticos:** selector Conexiones/Sistema/Logs; fases, datos y bitácora anteriores; copiar y limpiar mantienen sus funciones públicas.
6. **Navegación:** se conservan las cuatro rutas/destinos y el `PageController`. Con texto muy grande se da mayor anchura a la sección seleccionada y se mantienen los otros destinos mediante iconos, etiquetas semánticas y tooltips.

## Componentes creados

| Archivo | Componentes / responsabilidad |
| --- | --- |
| `lib/app/design/blanquita_colors.dart` | `BlanquitaColors`, paleta semántica e interpolación |
| `lib/app/design/blanquita_design.dart` | `BlanquitaDesign`, medidas, movimiento, densidad, tipografía y `BlanquitaTextScaler` |
| `lib/app/design/visual_transition.dart` | `VisualTransition` |
| `lib/shared/widgets/blanquita/blanquita_components.dart` | `BlanquitaCard`, `BlanquitaButton`, `BlanquitaStatus`, `BlanquitaDeviceCard`, `BlanquitaSection`, `BlanquitaSegmentedControl` |
| `lib/shared/widgets/blanquita/blanquita_brand.dart` | `BlanquitaBrand`, marca vectorial local |
| `lib/shared/widgets/blanquita/blanquita_lock_state.dart` | `BlanquitaLockState`, `BlanquitaErrorState` |
| `lib/shared/widgets/blanquita/blanquita_timeline.dart` | `BlanquitaTimeline` |
| `lib/shared/widgets/blanquita/blanquita_modal.dart` | `BlanquitaModal` con info, éxito, advertencia, error, confirmación y proceso |
| `lib/shared/widgets/blanquita/blanquita_connection_feedback.dart` | Presentación del resultado, espera y cancelación de la prueba de conexión existente |
| `lib/features/settings/presentation/personalization_panel.dart` | `PersonalizationPanel` |
| `lib/features/assistant/domain/alfresi_context.dart` | `AlfresiContext`, lectura de estados públicos y motivos de bloqueo |
| `lib/features/assistant/domain/alfresi_message.dart` | `AlfresiMessage`, `AlfresiMood` |
| `lib/features/assistant/services/alfresi_rules.dart` | `AlfresiRules`, explicación determinista |
| `lib/features/assistant/presentation/alfresi_avatar.dart` | `AlfresiAvatar`, fallback vectorial y estados visuales |
| `lib/features/assistant/presentation/alfresi_bubble.dart` | `AlfresiBubble`, mensaje integrado sin cubrir controles |
| `lib/features/assistant/presentation/alfresi_panel.dart` | `AlfresiButton`, `AlfresiPanel` |

También se adaptaron los componentes compartidos anteriores: superficies, encabezados, estado, navegación y esquema cartesiano.

## Tema Original

Conserva la paleta grafito/cian y el material glass de la experiencia anterior. Conserva la composición original de Inicio. Recibe las mejoras compartidas de accesibilidad, estados, ajustes y ALFRESI.

## Tema Hamburguesa

Tema inicial de esta variante. Fondo marrón oscuro, superficies opacas, bordes dorados, texto crema y controles con forma definida, tomando la imagen de referencia como dirección visual.

Las superficies de Hamburguesa y Personalizado no utilizan glass ni blur de tarjetas. Se conservan sombras moderadas opcionales. El difuminado de las transiciones es un efecto independiente y desactivable.

- Amarillo: selección, acción principal y marca.
- Verde: conexión o resultado correcto confirmado.
- Naranja: espera, atención y datos pendientes.
- Rojo: errores, bloqueo de seguridad, STOP y detención inmediata.

Se mantuvo la representación cartesiana existente del robot. No se inventó un brazo articulado, una cámara de video, autenticación V2, una dirección, un porcentaje de velocidad ni reportes para reproducir datos del mockup.

## Personalización

- Tema visual Original, Hamburguesa o Personalizado, independiente de Oscuro/Claro/Sistema.
- Personalizado permite elegir el acento Queso, Sésamo o Cian; conserva la semántica de seguridad.
- Tipografía Outfit local o tipografía del sistema.
- Texto Pequeño/Normal/Grande.
- Interfaz Compacta/Normal/Grande: cambia padding, radio, tamaño de iconos y alturas de componentes. Las acciones principales conservan un mínimo táctil de 48 px.
- Animaciones, difuminado, sombras, efectos del asistente y modo rendimiento.
- ALFRESI: habilitar asistente, consejos contextuales, avisos importantes, detalles técnicos y animaciones.

Todas las nuevas preferencias usan claves `ui.*` en el repositorio existente. Los ajustes de tamaño se combinan con `MediaQuery.textScaler`; no se limita ni reemplaza la accesibilidad del dispositivo por una escala fija.

## Transiciones y rendimiento

El `MaterialApp` interpola `ThemeData` y `BlanquitaColors` durante 400 ms con `easeOutCubic`. `VisualTransition` añade un fade parcial y un blur ligero sobre **el mismo elemento hijo**. No hay splash, navegación ni claves que sustituyan el árbol de rutas. Los providers globales siguen usando las instancias recibidas por `.value`.

Los modales comunes usan fade y escala 0.96 → 1 en 220 ms, con difuminado ligero opcional. La presentación de una prueba de conexión utiliza la acción pública existente y permite cancelar mediante la desconexión pública existente.

Reduce Motion del sistema, la preferencia de reducción de movimiento y el modo rendimiento reducen las animaciones y efectos. Las superficies de Hamburguesa no ejecutan blur por tarjeta. ALFRESI realiza movimientos breves y discretos, sin animación continua costosa.

## Fuente de verdad y vinculación

Se inspeccionaron los estados y acciones reales antes del diseño. Esta base expone transporte abierto y confirmación `READY`, además de los estados independientes de Visión. No expone las etapas desafío/autenticar/autorizar del mockup. La timeline muestra **Conectar → Confirmar READY** y la fase pública observada en detalles técnicos.

La búsqueda de dispositivos no está disponible en esta base funcional. Por eso no se agregó un radar que fingiera buscar, ni se modificó la comunicación para introducir discovery.

## ALFRESI

ALFRESI es una interpretación local y determinista; no usa LLM, API externa ni Internet durante el funcionamiento.

Lee `MachineState`, `VisionState`, `manualControlsLocked`, `canStartMovement`, `transportOpen`, `phase` y la sección actual. El contexto es una vista efímera de los valores públicos, sin un controlador paralelo ni una copia mutable del estado del robot.

Explica:

- Falta de conexión o confirmación READY.
- Diferencia entre control ESP32 y visión de la laptop.
- Error entregado por el sistema, sin atribuir una causa no demostrada.
- Secuencia activa y bloqueo manual.
- Final de carrera activo, con prioridad sobre otros mensajes.
- Visión no lista, alertas o reporte caducado.
- Sensores desconocidos: no concluye “seguridad libre” si falta el dato.

El panel contiene Resumen, Diagnóstico y Ayuda. “¿Por qué?” muestra evidencia. Los detalles técnicos pueden desactivarse. La única navegación ofrecida lleva a Diagnósticos; ALFRESI no ofrece acciones físicas ni mueve, abre/cierra pinza, inicia secuencias, ejecuta STOP o dispara emergencia. Esas acciones permanecen en Control y requieren interacción explícita.

El avatar está integrado en encabezados y mensajes: no cubre STOP, direcciones, emergencia ni navegación. Sus estados idle/success/warning/error/thinking se distinguen con símbolos y color.

## Assets

`assets/alfresi/alfresi_premium.png` es el asset local transparente de la mascota. Se creó con la herramienta integrada de generación de imágenes, solamente como recurso visual. Los iconos y la marca se dibujan con Flutter y recursos locales. Los archivos `alfresi_idle.png`, `alfresi_success.png`, `alfresi_warning.png`, `alfresi_error.png` y `alfresi_thinking.png` exportan el fallback vectorial.

Prompt utilizado para el asset premium:

> Use case: stylized-concept. Asset type: production mobile app mascot cutout, not a UI mockup. Create ALFRESI, a small premium industrial robotics assistant. Friendly but not childish. Full body of ONE compact rounded robot centered, face looking straight ahead, slight three quarter torso. Cream ivory enamel body, polished golden cheese-yellow metal trim, dark glossy black face screen, two large warm amber LED eyes and subtle friendly curved smile, tiny antenna with orange light, articulated small arms and feet, simple circular gold chest badge with single capital letter A. High-end detailed 3D product illustration, realistic bevels, restrained warm rim lighting and small warm highlights, legible silhouette at 64 pixels. Robot alone occupies 90 percent of square frame. Actual transparent background, no ground plane, no shadows beyond tiny contact shadow under feet, no surrounding scenery, no food, no burger base, no other text, no logos, no speech bubble, no panels, no interface. Elegant warm industrial technology character for the BLANQUITA robot control app. Golden yellow #FFC928 accents, ivory #FFF4E3 and dark brown #100A06. No emoji or flat vector styling.

## Tests y evidencias

La validación automatizada se registra en [validación](evidencias/validacion/RESULTADOS.md). Las capturas están enumeradas y enlazadas en la [galería de evidencias](evidencias/ui/README.md).

Las capturas son renders reales de los widgets Flutter implementados, generados por `flutter test` a resolución 2× con las fuentes Outfit, Material Icons y Cupertino Icons locales. Los canales de las pruebas son dobles de transporte: los dominios `.test` y el estado conectado de esas capturas son escenarios de prueba, no datos de dispositivos físicos.

Se validan 360×800, 390×844, 412×915, 800×1024 y 844×390, con texto de sistema al 100 % y 200 %, además del tamaño de texto Grande y densidad Grande. Se recorre el contenido desplazable de las cuatro pantallas y se abre Diagnósticos.

No se conectó ni se movió un robot físico en esta tarea. La validación visual y el APK no sustituyen una prueba con el ESP32 y el servidor de visión reales.

Para regenerar las capturas:

```powershell
flutter test test/frontend_evidence_test.dart --dart-define=GENERAR_EVIDENCIAS=true
```

Para volver al diseño anterior dentro de esta aplicación: Ajustes → Tema visual → Original. Para utilizar la aplicación Android de respaldo, abrir BLANQUITA Víctor.
