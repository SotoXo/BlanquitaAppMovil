# Resultados de validación

20 de octubre de 2026. Rama `feat/victor-hamburger-ui`, base funcional `495b6ae`.

| Comprobación | Resultado |
| --- | --- |
| `dart format .` | 71 archivos procesados; salida 0. Formato posterior de los archivos ajustados también correcto. |
| `flutter analyze` | Sin incidencias, salida 0. |
| `flutter test --dart-define=GENERAR_EVIDENCIAS=true --reporter expanded` | **116 pruebas correctas**, sin fallos. Incluye las 97 pruebas existentes y 19 de la nueva capa visual. |
| `flutter build apk --debug` | APK construido, salida 0. |
| `git diff --check` | Sin errores, salida 0. |
| Rutas operativas protegidas frente a `495b6ae` | Sin diferencias, salida 0. |
| Metadatos reales del APK con `aapt dump badging` | `com.example.blanquita.alfresi`, nombre `BLANQUITA ALFRESI`, icono `ic_alfresi.xml`. |

## Cobertura de la nueva capa visual

- Persistencia de tema independiente de brillo y endpoints, fuente, texto, densidad, sombras y preferencias de ALFRESI.
- Escala de texto de la aplicación combinada con la del sistema.
- Mínimo táctil de acciones principales de 48 px para las tres densidades.
- ALFRESI: normal, error, final de carrera, seguridad desconocida y separación de Visión/ESP32.
- Cambio Original → Hamburguesa → Original mientras ambos controladores están conectados: conserva la pantalla de Control, las mismas instancias de MachineController, VisionController y WifiNetworkController, un solo socket abierto por canal y ningún comando físico adicional.
- Selector de temas pulsado desde Ajustes en la aplicación renderizada.
- Éxito, error, proceso y bloqueo manual; panel de ALFRESI, detalle de evidencia y navegación a Logs.
- Prueba pública de conexión pulsada desde Ajustes, usando el controlador operativo real con un transporte de prueba: modal de éxito correcto.
- Detención inmediata visible al entrar en Control conectado a 390 px, comprobada con hit testing.
- Cinco tamaños de pantalla por dos escalas de accesibilidad: **10 escenarios**, recorriendo todo el contenido de Inicio, Control, Visión y Ajustes, y abriendo Diagnósticos. Incluyen texto Grande y densidad Grande.
- Exportación de los cinco estados del fallback vectorial de ALFRESI.

## Límites protegidos

El comando de comparación contra la base devuelve cero diferencias en:

```text
lib/core/websocket/
lib/core/network/
lib/core/protocol/
lib/core/models/
lib/features/vision/controller/
lib/features/vision/domain/
lib/features/vision/services/
android/app/src/main/kotlin/
```

`SettingsRepository`, `AppSettings` y `SettingsController` solamente añaden preferencias visuales. El cambio de identificador y nombre Android permite la instalación independiente; no cambia permisos ni protocolos.

## Incidencias corregidas durante la validación

- El escalado de accesibilidad hizo desbordar etiquetas de navegación y controles estrechos. Se corrigieron con medición del texto, navegación adaptativa, alturas de controles y distribución flexible. Los diez escenarios finales pasan sin excepciones de layout.
- Las primeras capturas de pruebas mostraban cuadros en lugar de iconos por falta de carga explícita de las fuentes del entorno de test. La exportación final carga Material Icons y Cupertino Icons, además de Outfit.
- El primer `dart format .` encontró una ruta generada profunda dentro de `build/` que Windows no pudo enumerar. Se apartó temporalmente esa carpeta fuera del proyecto, se ejecutó el comando y se restituyó íntegra; no se borraron artefactos. Después se verificó el formato de los últimos archivos ajustados.
- La primera resolución de plugins encontró la limitación de symlinks de Windows. Los comandos finales con resolución normal de dependencias completaron correctamente. No se cambiaron permisos del sistema ni se actualizaron paquetes para ocultar el problema.

## Archivos de evidencia

- [Formato](dart-format.txt).
- [Análisis](flutter-analyze.txt).
- [Suite completa](flutter-test.txt).
- [Construcción APK](flutter-build-apk.txt).
- [Identidad extraída del APK](identidad-apk.txt).
- [SHA-256 del APK entregado](apk-sha256.txt).
- [Diff check](git-diff-check.txt), vacío porque no hay errores.
- [25 capturas de Flutter](../ui/README.md).

Las pruebas usan dobles de transporte y no abren sockets hacia el robot físico. No se validó una instalación en un teléfono ni la conectividad física con ESP32/laptop en esta sesión. El APK es de depuración y permite comprobar la nueva interfaz sin reemplazar la aplicación anterior.
