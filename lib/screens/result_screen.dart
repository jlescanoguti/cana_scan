import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';

class ResultScreen extends StatefulWidget {
  final File? imageFile;
  final String? imageUrl;
  final Map<String, dynamic>? initialResult;
  final bool isFromGallery;

  const ResultScreen({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.initialResult,
    this.isFromGallery = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? _resultado;
  bool _cargando = true;
  String? _error;

  // Estado del GPS
  bool _obteniendoGps = false;
  double? _latitud;
  double? _longitud;
  double? _precisionGps;
  String? _errorGps;

  // Estado de guardado
  bool _guardando = false;
  bool _yaGuardado = false;
  String? _mensajeGuardado;

  static const double _umbralConfiable = 0.40;

  final Map<String, Color> _coloresClase = {
    'Amarillamiento Inicial': const Color(0xFFFFD54F),
    'Amarillamiento Avanzado': const Color(0xFFFFA000),
    'Podredumbre Roja Inicial': const Color(0xFFE57373),
    'Podredumbre Roja Avanzada': const Color(0xFFC62828),
    'Roya Inicial': const Color(0xFF64B5F6),
    'Roya Avanzada': const Color(0xFF1565C0),
    'Gusano Cogollero Inicial': const Color(0xFF8D6E63),
    'Gusano Cogollero Avanzado': const Color(0xFF3E2723),
    'Saludable': const Color(0xFF2E7D32),
    // Variantes por compatibilidad
    'Amarillamiento': const Color(0xFFFFD54F),
    'Podredumbre Roja': const Color(0xFFC62828),
    'Roya': const Color(0xFF1565C0),
    'Cogollo': const Color(0xFF3E2723),
    'AmarillamientoInicial': const Color(0xFFFFD54F),
    'AmarillamientoAvanzado': const Color(0xFFFFA000),
    'PodredumbreRojaInicial': const Color(0xFFE57373),
    'PodredumbreRojaAvanzado': const Color(0xFFC62828),
    'RoyaInicial': const Color(0xFF64B5F6),
    'RoyaAvanzado': const Color(0xFF1565C0),
    'CogolleroInicial': const Color(0xFF8D6E63),
    'CogolleroAvanzado': const Color(0xFF3E2723),
  };

  Color _colorPorClase(String clase) {
    final claveNormalizada = clase.trim();
    if (_coloresClase.containsKey(claveNormalizada)) {
      return _coloresClase[claveNormalizada]!;
    }

    final claveSinEspacios = claveNormalizada.replaceAll(RegExp(r'\s+'), '');
    final claveLower = claveSinEspacios.toLowerCase();

    if (claveLower.contains('amarillamiento')) {
      return const Color(0xFFFFD600);
    }
    if (claveLower.contains('cogollero') ||
        claveLower.contains('cogollo') ||
        claveLower.contains('gusano')) {
      return Colors.black;
    }
    if (claveLower.contains('podredumbre') || claveLower.contains('roja')) {
      return Colors.red;
    }
    if (claveLower.contains('roya')) {
      return Colors.blue;
    }
    if (claveLower.contains('saludable')) {
      return Colors.green;
    }

    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialResult != null) {
      _resultado = widget.initialResult;
      _cargando = false;
      _yaGuardado = true;
    } else if (widget.imageFile != null) {
      _predecir();
    }
  }

  Future<void> _predecir() async {
    try {
      final resultado = await ApiService.predict(widget.imageFile!);
      if (mounted) {
        setState(() {
          _resultado = resultado;
          _cargando = false;
        });

        // Evaluar condiciones de usuario para solicitud de GPS
        final esInvitado = !SupabaseService.isAuthenticated;
        final tieneGrupo = SupabaseService.currentGrupoId != null;
        final confiables = _deteccionesConfiables();
        final hayAfeccion = confiables.any((d) => d['clase'] != 'Saludable');

        if (!esInvitado) {
          if (tieneGrupo && hayAfeccion) {
            // Usuario en grupo de trabajo: solicitud automática para el mapa colaborativo
            _obtenerUbicacionGps();
          } else if (confiables.isNotEmpty &&
              confiables.first['clase'] == 'Saludable') {
            // Si está saludable y autenticado, se guarda en su historial personal sin alarmar al grupo
            _guardarEnHistorial(esGrupal: false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  Future<void> _obtenerUbicacionGps() async {
    setState(() {
      _obteniendoGps = true;
      _errorGps = null;
    });

    final res = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _obteniendoGps = false;
        if (res.success) {
          _latitud = res.latitude;
          _longitud = res.longitude;
          _precisionGps = res.accuracy;
          _errorGps = null;
        } else {
          _errorGps = res.errorMessage ?? 'GPS no disponible';
        }
      });
    }
  }

  Future<void> _guardarEnHistorial({required bool esGrupal}) async {
    if (!SupabaseService.isAuthenticated || widget.imageFile == null) return;

    setState(() => _guardando = true);

    try {
      final detecciones = (_resultado!['detecciones'] as List?) ?? [];
      final deteccionesConfiables = detecciones
          .where((d) => (d['confianza'] as num) >= _umbralConfiable)
          .toList();

      final noEsCana = deteccionesConfiables.isEmpty;
      final hayAfeccion =
          deteccionesConfiables.any((d) => d['clase'] != 'Saludable');

      late String estadoGeneral;
      String? diagPrincipal;
      double? maxConfianza;

      if (noEsCana) {
        estadoGeneral = 'no_reconocido';
      } else if (hayAfeccion) {
        estadoGeneral = 'afeccion';
        final primerAfeccion = deteccionesConfiables.firstWhere(
          (d) => d['clase'] != 'Saludable',
          orElse: () => deteccionesConfiables.first,
        );
        diagPrincipal = primerAfeccion['clase'] as String?;
        maxConfianza = (primerAfeccion['confianza'] as num?)?.toDouble();
      } else {
        estadoGeneral = 'saludable';
        diagPrincipal = 'Saludable';
        if (deteccionesConfiables.isNotEmpty) {
          maxConfianza =
              (deteccionesConfiables.first['confianza'] as num?)?.toDouble();
        }
      }

      // 1. Subir imagen
      final uploadedUrl =
          await SupabaseService.uploadScanImage(widget.imageFile!);

      // 2. Guardar en Base de Datos
      final grupoId = esGrupal ? SupabaseService.currentGrupoId : null;

      final ok = await SupabaseService.saveDiagnosisRecord(
        imageUrl: uploadedUrl,
        estadoGeneral: estadoGeneral,
        diagnosticoPrincipal: diagPrincipal,
        confianzaMaxima: maxConfianza,
        imagenAncho: (_resultado!['imagen_ancho'] as num).toDouble(),
        imagenAlto: (_resultado!['imagen_alto'] as num).toDouble(),
        detecciones: detecciones,
        grupoId: grupoId,
        latitud: hayAfeccion ? _latitud : null,
        longitud: hayAfeccion ? _longitud : null,
        origenFoto: widget.isFromGallery ? 'galeria' : 'camara',
      );

      if (mounted) {
        setState(() {
          _guardando = false;
          _yaGuardado = ok;
          _mensajeGuardado = esGrupal
              ? 'Reporte publicado en tu cuadrilla con éxito.'
              : 'Diagnóstico guardado en tu historial personal.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }

  List _deteccionesConfiables() {
    if (_resultado == null) return [];
    final detecciones = _resultado!['detecciones'] as List;
    return detecciones
        .where((d) => (d['confianza'] as num) >= _umbralConfiable)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F8F1),
        elevation: 0,
        title: const Text(
          'Resultado del Diagnóstico',
          style: TextStyle(
            color: Color(0xFF1B3A1B),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B3A1B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cargando
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2D7A2D)),
                  SizedBox(height: 16),
                  Text(
                    'Analizando la hoja...',
                    style: TextStyle(color: Color(0xFF4A5D4A), fontSize: 14),
                  ),
                ],
              ),
            )
          : _error != null
              ? _buildError()
              : _buildResultado(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Color(0xFFE24B4A)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                setState(() {
                  _cargando = true;
                  _error = null;
                });
                _predecir();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultado() {
    final imgAncho = (_resultado!['imagen_ancho'] as num).toDouble();
    final imgAlto = (_resultado!['imagen_alto'] as num).toDouble();
    final deteccionesConfiables = _deteccionesConfiables();

    final esSaludable = deteccionesConfiables.length == 1 &&
        deteccionesConfiables.first['clase'] == 'Saludable';
    final hayAfeccion =
        deteccionesConfiables.any((d) => d['clase'] != 'Saludable');
    final noEsCana = deteccionesConfiables.isEmpty;

    final tieneGrupo = SupabaseService.currentGrupoId != null;
    final esInvitado = !SupabaseService.isAuthenticated;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen con bounding boxes
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (widget.imageFile != null)
                  Image.file(
                    widget.imageFile!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  )
                else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  Image.network(
                    widget.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 250,
                        color: const Color(0xFFE8F5E9),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF2D7A2D),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, _, _) => Container(
                      height: 250,
                      color: const Color(0xFFE0E0E0),
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                if (deteccionesConfiables.isNotEmpty)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final scaleX = constraints.maxWidth / imgAncho;
                        final scaleY =
                            (constraints.maxWidth * imgAlto / imgAncho) /
                                imgAlto;
                        return CustomPaint(
                          painter: BoundingBoxPainter(
                            detecciones: deteccionesConfiables,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            coloresClase: _coloresClase,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Estado general
          _buildBadgeEstado(noEsCana, esSaludable, hayAfeccion),

          const SizedBox(height: 16),

          // Tarjeta de hoja saludable
          if (!noEsCana && !hayAfeccion) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E5D7), width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF2D7A2D), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hoja de caña de azúcar detectada',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          esSaludable && deteccionesConfiables.isNotEmpty
                              ? 'Está saludable · Confianza: ${((deteccionesConfiables.first['confianza'] as num) * 100).toStringAsFixed(1)}%'
                              : 'Está saludable · Sin afecciones detectadas.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2D7A2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Lista de afecciones identificadas
          if (hayAfeccion) ...[
            const Text(
              'Afecciones identificadas',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B3A1B),
              ),
            ),
            const SizedBox(height: 8),
            ...deteccionesConfiables.map((det) {
              final clase = det['clase'] as String;
              final confianza = (det['confianza'] as num).toDouble();
              final color = _colorPorClase(clase);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: const Color(0xFFD7E5D7), width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        clase,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B)),
                      ),
                    ),
                    Text(
                      '${(confianza * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B806B)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // Tarjeta de estado de GPS
            if (widget.imageFile != null && !esInvitado) ...[
              _buildTarjetaGps(),
              const SizedBox(height: 16),
            ],
          ],

          // Banner si es invitado
          if (esInvitado && widget.imageFile != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD7E5D7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          color: Color(0xFF2D7A2D), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Modo Invitado',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B3A1B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inicia sesión o regístrate con tu DNI para guardar diagnósticos en tu historial y enviarlos al mapa de tu cuadrilla.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4A5D4A)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7A2D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Acceder con mi DNI'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Mensaje de éxito de guardado
          if (_yaGuardado && _mensajeGuardado != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2D7A2D), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _mensajeGuardado!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B3A1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Botones de acción cuando hay afección y no se ha guardado
          if (hayAfeccion && !_yaGuardado && !esInvitado && widget.imageFile != null) ...[
            if (tieneGrupo) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7A2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _guardando ? null : () => _guardarEnHistorial(esGrupal: true),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Publicar reporte en mi cuadrilla',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4A5D4A),
                    side: const BorderSide(color: Color(0xFFD7E5D7)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _guardando ? null : () => _guardarEnHistorial(esGrupal: false),
                  icon: const Icon(Icons.bookmark_border_rounded, size: 18),
                  label: const Text('Guardar solo en mi historial personal'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7A2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _guardando ? null : () => _guardarEnHistorial(esGrupal: false),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text(
                    'Guardar en mi historial personal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Botón volver
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver al inicio'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaGps() {
    if (_obteniendoGps) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E5D7)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF2D7A2D)),
            ),
            SizedBox(width: 12),
            Text(
              'Obteniendo coordenadas satelitales GPS...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
            ),
          ],
        ),
      );
    }

    final tieneGrupo = SupabaseService.currentGrupoId != null;

    if (!tieneGrupo) {
      if (_latitud != null && _longitud != null) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC8E6C9)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFF2D7A2D), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ubicación de parcela adjuntada',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B3A1B)),
                    ),
                    Text(
                      'Lat: ${_latitud!.toStringAsFixed(5)}, Lon: ${_longitud!.toStringAsFixed(5)}'
                      '${_precisionGps != null ? ' (±${_precisionGps!.toStringAsFixed(0)}m)' : ''}',
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF2D7A2D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Tarjeta opcional para agricultor independiente
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD7E5D7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_location_alt_outlined,
                color: Color(0xFF2D7A2D), size: 24),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ubicación opcional',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A1B)),
                  ),
                  Text(
                    'Adjunta el GPS para georreferenciar este foco en tu mapa personal.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF4A5D4A)),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A2D),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _obtenerUbicacionGps(),
              icon: const Icon(Icons.gps_fixed_rounded, size: 14),
              label: const Text('Adjuntar', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
      );
    }

    if (_latitud != null && _longitud != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: Color(0xFF2D7A2D), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación GPS obtenida',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A1B)),
                  ),
                  Text(
                    'Lat: ${_latitud!.toStringAsFixed(5)}, Lon: ${_longitud!.toStringAsFixed(5)}'
                    '${_precisionGps != null ? ' (±${_precisionGps!.toStringAsFixed(0)}m)' : ''}',
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF2D7A2D)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off_rounded,
                  color: Color(0xFFF57C00), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorGps ?? 'Ubicación GPS no detectada',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE65100)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Si envías el reporte sin GPS, tu cuadrilla no podrá ver la ubicación de este foco en el mapa.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await LocationService.openLocationSettings();
              await _obtenerUbicacionGps();
            },
            icon: const Icon(Icons.gps_fixed_rounded, size: 16),
            label: const Text('Activar GPS y Reintentar',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeEstado(bool noEsCana, bool esSaludable, bool hayAfeccion) {
    late Color bg;
    late Color fg;
    late IconData icono;
    late String titulo;
    late String subtitulo;

    if (noEsCana) {
      bg = const Color(0xFFF1EFE8);
      fg = const Color(0xFF5F5E5A);
      icono = Icons.search_off_rounded;
      titulo = 'No se identificó cultivo de caña';
      subtitulo =
          'Asegúrate de enfocar con buena iluminación una hoja de caña de azúcar visible.';
    } else if (hayAfeccion) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFBA7517);
      icono = Icons.warning_rounded;
      titulo = 'Hoja con afección detectada';
      subtitulo = 'Se identificaron síntomas en el cultivo';
    } else {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2D7A2D);
      icono = Icons.check_circle_rounded;
      titulo = 'Hoja de caña de azúcar detectada';
      subtitulo = 'Está saludable';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icono, size: 24, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: fg.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List detecciones;
  final double scaleX;
  final double scaleY;
  final Map<String, Color> coloresClase;

  BoundingBoxPainter({
    required this.detecciones,
    required this.scaleX,
    required this.scaleY,
    required this.coloresClase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detecciones) {
      final clase = det['clase'] as String;
      final bbox = det['bbox'] as List;
      final color = _colorPorClaseEnPainter(clase, coloresClase);

      final x1 = (bbox[0] as num).toDouble() * scaleX;
      final y1 = (bbox[1] as num).toDouble() * scaleY;
      final x2 = (bbox[2] as num).toDouble() * scaleX;
      final y2 = (bbox[3] as num).toDouble() * scaleY;

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x1, y1, x2, y2),
          const Radius.circular(4),
        ),
        paint,
      );

      final confianza = (det['confianza'] as num).toDouble();
      final label = '$clase ${(confianza * 100).toStringAsFixed(0)}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();

      final textWidth = textPainter.width + 8;
      final textHeight = textPainter.height + 4;
      final badgeY = y1 >= textHeight ? y1 - textHeight : y1 + 2;

      final bgPaint = Paint()..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x1, badgeY, textWidth, textHeight),
          const Radius.circular(4),
        ),
        bgPaint,
      );

      textPainter.paint(canvas, Offset(x1 + 4, badgeY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _colorPorClaseEnPainter(String clase, Map<String, Color> coloresClase) {
  final claveNormalizada = clase.trim();

  if (coloresClase.containsKey(claveNormalizada)) {
    return coloresClase[claveNormalizada]!;
  }

  final claveSinEspacios = claveNormalizada.replaceAll(RegExp(r'\s+'), '');
  final claveLower = claveSinEspacios.toLowerCase();

  if (claveLower.contains('amarillamiento')) {
    return const Color(0xFFFFD600);
  }
  if (claveLower.contains('cogollero') ||
      claveLower.contains('cogollo') ||
      claveLower.contains('gusano')) {
    return Colors.black;
  }
  if (claveLower.contains('podredumbre') || claveLower.contains('roja')) {
    return Colors.red;
  }
  if (claveLower.contains('roya')) {
    return Colors.blue;
  }
  if (claveLower.contains('saludable')) {
    return Colors.green;
  }

  return Colors.grey;
}