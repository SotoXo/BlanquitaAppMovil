# Referencia vs implementación — refinamiento ALFRESI

## Revisión previa a editar código

Referencia abierta: `codex-clipboard-0a7bed8d-c4a1-4aa7-8687-dda212c95d73.png`. Se abrieron las capturas reales anteriores de Inicio Original/Hamburguesa, Control, Visión, Ajustes, Diagnósticos, selector, los tres modales, bloqueo y panel ALFRESI.

Checkpoint de la implementación previa: `dd946db`.

| Vista | Referencia | Implementación anterior / diferencia a corregir |
| --- | --- | --- |
| Splash | Marca, frutilla grande y progreso sobre halo cálido | No existe composición Flutter de inicio |
| Inicio | Header compacto, burbuja arriba, conexiones antes del hero y estado al pie | Títulos grandes, estado y hero antes de conexiones, frutilla ausente |
| Dispositivos | Radar y dispositivos reales en tarjetas compactas | No existe vista; esta base no expone discovery. No fingir scan ni encontrados |
| Vinculación | Timeline vertical y detalles seguros | Timeline integrada en Ajustes; solo existen transporte y READY, sin fases V2 públicas |
| Control | Pad central radial, direcciones doradas, STOP dominante | Pad rectangular alto, controles secundarios demasiado separados |
| Visión | Placeholder/preview, sistema y reporte compactos | Acciones de conexión ocupan casi toda la primera vista; no hay stream real |
| Diagnósticos | Header único, tabs y timeline | Header duplicado, mucho texto antes de datos, logs extensos |
| Ajustes | Filas compactas con valores y flechas | Selector completo y bloques grandes ocupan el inicio |
| Tema visual | Frutilla, previews, aplicar | Solo tres radios de paleta; sin preview de pantalla ni vista dedicada |
| Modal error | Frutilla triste, panel rojo oscuro, acciones | AlertDialog marrón genérico, sin mascota |
| Modal éxito | Frutilla feliz y card verde oscuro | AlertDialog genérico, sin mascota |
| Modal esperando | Frutilla pensando, acento azul y progreso | AlertDialog con reloj y sin mascota |
| Control bloqueado | Frutilla y panel de seguridad compacto | Tarjeta alta sin mascota; pad queda muy abajo |
| ALFRESI | Frutilla roja y expresiones | Assets encontrados en checkout son robot; se usa ahora la frutilla exacta de la referencia, mediante viewports de su atlas |
| Navegación | Cinco destinos, línea compacta, activo dorado | Cuatro destinos, tarjetas activas grandes |

## Límites de fidelidad

No se sustituye el cartesiano por un brazo articulado. No se agregan video, porcentajes de velocidad, FPS, direcciones, objetos, dispositivos encontrados ni estados V2 sin evidencia del sistema. La comparación final detallará esas diferencias deliberadas.

## Revisión e iteraciones realizadas

Se renderizaron y abrieron las capturas iniciales de las 13 vistas y las capturas posteriores a la corrección. La segunda pasada corrigió tamaño del pad, densidad de filas, cromática de chips, timeline, estados de modales y altura del bloqueo. El fondo fotográfico y la lluvia se añadieron siguiendo la petición posterior del usuario.

[Referencia original suministrada](../../../assets/alfresi/referencia_frutilla.png). Las capturas son Flutter real, no composiciones generativas. Los escenarios conectados, endpoints `.test` y eventos fijos pertenecen a dobles de prueba; no acreditan conexión con hardware.

### Splash

- **Referencia:** Marca, frutilla protagonista y carga sobre luz cálida.
- **Implementación:** [01-splash.png](01-splash.png). [Primera pasada](iteracion-1/01-splash.png).
- **Corrección posterior a comparar:** Viewport de la ilustración original, recarga de imagen antes de capturar y mejor margen del personaje.
- **Diferencias restantes:** La frutilla procede del montaje proporcionado; conserva su fondo y resolución original.

### Inicio

- **Referencia:** Burbuja, conexiones, hero y estado inferior.
- **Implementación:** [02-inicio.png](02-inicio.png). [Primera pasada](iteracion-1/02-inicio.png).
- **Corrección posterior a comparar:** Conexiones antes del hero, tarjetas más compactas y título Visión · laptop para evitar ambigüedad con navegación.
- **Diferencias restantes:** Se conserva el visualizador cartesiano real, no el brazo articulado de la imagen.

### Dispositivos

- **Referencia:** Radar con acompañante y tarjetas de equipos.
- **Implementación:** [03-dispositivos.png](03-dispositivos.png). [Primera pasada](iteracion-1/03-dispositivos.png).
- **Corrección posterior a comparar:** Diagrama más compacto, líneas azules finas y frutilla en el centro.
- **Diferencias restantes:** No existe discovery público en esta base: el radar es estático y dice explícitamente que usa equipos configurados.

### Vinculación

- **Referencia:** Timeline vertical y detalles de sesión.
- **Implementación:** [04-vinculacion.png](04-vinculacion.png). [Primera pasada](iteracion-1/04-vinculacion.png).
- **Corrección posterior a comparar:** Línea continua, círculos con icono de estado y encabezado compacto con volver nativo.
- **Diferencias restantes:** Solo se muestran Conectar y Confirmar READY. No se inventan desafío, HMAC, auth.v2 o ready.v2.

### Control

- **Referencia:** Pad radial, STOP central y herramientas.
- **Implementación:** [05-control.png](05-control.png). [Primera pasada](iteracion-1/05-control.png).
- **Corrección posterior a comparar:** Pad de 264 px máximos, botones dorados, herramientas más cerca y borde rojo exclusivo de detención.
- **Diferencias restantes:** La velocidad continúa siendo incremento/decremento solicitado; no hay porcentaje absoluto público.

### Visión

- **Referencia:** Estado, preview, sistema y reporte.
- **Implementación:** [06-vision.png](06-vision.png). [Primera pasada](iteracion-1/06-vision.png).
- **Corrección posterior a comparar:** Filas compactas, conexión visible arriba, acciones desplegables y alertas expandidas cuando existen.
- **Diferencias restantes:** El servidor no entrega streaming: se muestra el placeholder, sin fotografía de cámara ni valores fabricados.

### Diagnósticos

- **Referencia:** Header, pestañas y timeline de logs.
- **Implementación:** [07-diagnosticos.png](07-diagnosticos.png). [Primera pasada](iteracion-1/07-diagnosticos.png).
- **Corrección posterior a comparar:** Un solo encabezado, chips cálidos, rail vertical e icono circular real; limpiar en rojo secundario.
- **Diferencias restantes:** La bitácora conserva sus detalles técnicos y campos originales. El escenario golden usa eventos fijos de prueba.

### Ajustes

- **Referencia:** Filas con iconos, valores y flechas.
- **Implementación:** [08-ajustes.png](08-ajustes.png). [Primera pasada](iteracion-1/08-ajustes.png).
- **Corrección posterior a comparar:** Altura táctil de 48 px, chips cálidos y panel de preferencias enfocado en la fila seleccionada.
- **Diferencias restantes:** Las conexiones y opciones operativas completas siguen debajo; por ello el contenido requiere scroll.

### Tema visual

- **Referencia:** Previews, selección dorada y aplicar.
- **Implementación:** [09-tema-visual.png](09-tema-visual.png). [Primera pasada](iteracion-1/09-tema-visual.png).
- **Corrección posterior a comparar:** Previews más altas, selección explícita y botón Aplicar que conserva la ruta.
- **Diferencias restantes:** Los previews se dibujan con widgets y el fondo local; no son miniaturas falsas del estado del robot.

### Modal error

- **Referencia:** Frutilla triste y panel rojo oscuro.
- **Implementación:** [10-modal-error.png](10-modal-error.png). [Primera pasada](iteracion-1/10-modal-error.png).
- **Corrección posterior a comparar:** Ancho contenido, borde rojo, explicación sin causas inventadas y acciones secundarias cálidas.
- **Diferencias restantes:** El mensaje de producción utiliza el error real; las capturas son escenarios de presentación.

### Modal éxito

- **Referencia:** Frutilla feliz, check y panel verde oscuro.
- **Implementación:** [11-modal-success.png](11-modal-success.png). [Primera pasada](iteracion-1/11-modal-success.png).
- **Corrección posterior a comparar:** Panel más estrecho y jerarquía de estado/título/explicación/acción.
- **Diferencias restantes:** El texto dice READY confirmado; no afirma autenticación V2 que esta base no expone.

### Modal esperando

- **Referencia:** Frutilla pensando y panel azul.
- **Implementación:** [12-modal-waiting.png](12-modal-waiting.png). [Primera pasada](iteracion-1/12-modal-waiting.png).
- **Corrección posterior a comparar:** Acento azul dedicado; con Reduce Motion se usan puntos estáticos y no un porcentaje de avance ficticio.
- **Diferencias restantes:** Sin estimación de tiempo ni porcentaje: el controlador solo informa la fase actual.

### Control bloqueado

- **Referencia:** Frutilla preocupada, candado, motivo y diagnóstico.
- **Implementación:** [13-control-bloqueado.png](13-control-bloqueado.png). [Primera pasada](iteracion-1/13-control-bloqueado.png).
- **Corrección posterior a comparar:** Columna con altura mínima de contenido y acción secundaria; se eliminó el panel que llenaba el viewport.
- **Diferencias restantes:** Se preservan el motivo público y la prioridad de seguridad; no se sugiere volver a mover.

## Evidencias adicionales

- [Inicio Original](02-inicio-original.png).
- [ALFRESI abierto](14-alfresi-abierto.png); el estado cerrado se ve en cada header de las capturas principales.
- Las evidencias del teléfono y el video se documentan en [validación](validacion/RESULTADOS.md).

## Dirección de arte y fuentes

La referencia del usuario dirige composición, frutilla, paleta y jerarquía. La solicitud posterior de lluvia añade una capa ilustrativa de hamburguesas detrás del contenido. El fondo es un recurso local generado para este proyecto; no se necesita Internet al ejecutar la app.

La investigación de movimiento se contrastó con [animaciones de Flutter](https://docs.flutter.dev/ui/animations/overview), [accesibilidad de Flutter](https://docs.flutter.dev/ui/accessibility) y [disableAnimations](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/disableAnimations.html). Se aplicaron las skills locales UI/UX Pro Max y high-end-visual-design, subordinadas a la referencia y a las restricciones del sistema existente.
