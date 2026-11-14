# CañaScan · Prácticas de software verde

Este documento reúne las decisiones de CañaScan que reducen el consumo de
energía, de datos móviles y de recursos de servidor. Se actualiza cuando se
añade o cambia una práctica.

## Objetivos de sostenibilidad

1. **Diagnosticar con el menor costo energético posible para el teléfono**,
   que en campo suele funcionar con batería y datos móviles limitados.
2. **No transferir ni almacenar datos que no aportan valor.**
3. **Alargar la vida útil de los teléfonos de gama baja** usados por los
   agricultores, evitando trabajo pesado en el dispositivo.

## Arquitectura

| Decisión | Efecto |
|---|---|
| La inferencia YOLO se hace en el servidor (Railway), no en el teléfono | El teléfono no ejecuta la red neuronal: menos batería, menos calor y funciona en equipos antiguos. El APK no incluye los modelos (~decenas de MB menos) |
| Supabase (servicio gestionado) para autenticación, base de datos y fotos | Infraestructura compartida y escalada por el proveedor, sin servidores propios encendidos permanentemente |
| Las reglas de permisos se validan en la base de datos (RLS y funciones RPC) | Una sola llamada por acción en lugar de varias consultas desde la app |

## Desarrollo

### Datos transferidos y almacenados
- **Fotos reducidas antes de subirlas** (`home_screen.dart`): máximo
  1024 × 1024 px (antes 1200) con calidad JPEG 85. Ambos modelos se
  entrenaron a 640 px y la API reduce cada foto a ese tamaño antes de
  analizarla, así que el modelo recibe la misma información con un ~27 %
  menos de píxeles transferidos y almacenados. La calidad no se bajó para no
  añadir artefactos de compresión que afecten a lesiones sutiles.
- **Historial paginado** (`supabase_service.dart`, `history_screen.dart`): se
  descargan los 30 diagnósticos más recientes y el resto bajo demanda con
  "Cargar más diagnósticos".
- **Columnas explícitas** en las consultas de perfiles: no se descargan
  campos innecesarios.
- **Sin datos huérfanos**: al borrar un diagnóstico se borra también su foto
  en Storage.
- **Las hojas sanas no guardan ubicación** y la ubicación no se envía si no
  hay afección.

### Procesamiento en el teléfono
- **Miniaturas decodificadas a tamaño reducido** (`cacheWidth` en historial y
  mapa): ahorra memoria y CPU frente a decodificar la foto completa.
- **Consultas independientes en paralelo** (`Future.wait`) en el historial,
  para que la radio del teléfono esté activa menos tiempo.
- **Sin consultas duplicadas** al cambiar de pestaña: Home solo refresca la
  cuadrilla al volver a "Escanear"; Historial y Cuadrilla cargan sus propios
  datos.
- **Pantalla de inicio corta** (1,2 s) con una animación eficiente
  (`AnimationController`) en lugar de 100 redibujados manuales.

### Hardware
- **GPS bajo demanda**: solo se activa cuando se detecta una afección, con
  precisión media (`LocationAccuracy.medium`) y un límite de 4 segundos.
- **Cámara** solo al pulsar "Tomar foto".
- **Sin notificaciones push ni tareas en segundo plano.**

### Dependencias
- Se eliminaron `tflite_flutter`, `image` y `cupertino_icons`, que no se
  usaban en producción: APK más pequeño y menos código cargado al iniciar.

## Pruebas y despliegue
- `flutter analyze` y `flutter test` antes de cada cambio.
- Para distribuir, generar APKs separados por arquitectura, que reducen el
  tamaño de descarga para cada teléfono:

  ```bash
  flutter build apk --release --split-per-abi
  ```

## Educación de los usuarios
La hoja "Acerca de CañaScan" (`app_info_sheet.dart`) incluye la sección
**"Uso eficiente de la app"**: tomar una buena foto para no repetir análisis,
el uso del GPS solo cuando hace falta y borrar diagnósticos que no se
necesitan.

## Pendiente / no implementado
- No se ha medido el consumo energético real (por ejemplo, con Android
  Studio Energy Profiler o Battery Historian).
- No se adapta el comportamiento al modo de ahorro de batería del teléfono.
- No se ha evaluado la intensidad de carbono de las regiones de Railway y
  Supabase.
- No hay tema oscuro (ahorra energía en pantallas OLED).
