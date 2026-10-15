import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> escaneos;
  final String titulo;

  const MapScreen({
    super.key,
    required this.escaneos,
    this.titulo = 'Mapa de Focos de Infección',
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _soloPendientes = true;
  Map<String, dynamic>? _focoSeleccionado;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  List<Map<String, dynamic>> get _focosFiltrados {
    return widget.escaneos.where((item) {
      if (item['latitud'] == null || item['longitud'] == null) return false;
      if (_soloPendientes) {
        return item['estado_tratamiento'] != 'tratado';
      }
      return true;
    }).toList();
  }

  LatLng _calcularCentro() {
    final validos = _focosFiltrados;
    if (validos.isEmpty) {
      // Coordenada por defecto (zona cañera en Perú / Lambayeque / La Libertad)
      return const LatLng(-8.1116, -79.0286);
    }
    double sumaLat = 0;
    double sumaLng = 0;
    for (var f in validos) {
      sumaLat += (f['latitud'] as num).toDouble();
      sumaLng += (f['longitud'] as num).toDouble();
    }
    return LatLng(sumaLat / validos.length, sumaLng / validos.length);
  }

  Future<void> _abrirEnGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final focos = _focosFiltrados;
    final centro = _calcularCentro();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B3A1B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.titulo,
          style: const TextStyle(
            color: Color(0xFF1B3A1B),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Row(
            children: [
              const Text('Solo activos',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4A5D4A))),
              Switch(
                value: _soloPendientes,
                activeThumbColor: const Color(0xFF2D7A2D),
                activeTrackColor: const Color(0xFFE8F5E9),
                onChanged: (val) {
                  setState(() {
                    _soloPendientes = val;
                    _focoSeleccionado = null;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                if (_focoSeleccionado != null) {
                  setState(() => _focoSeleccionado = null);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.cana_scan',
              ),
              MarkerLayer(
                markers: focos.map((foco) {
                  final lat = (foco['latitud'] as num).toDouble();
                  final lng = (foco['longitud'] as num).toDouble();
                  final tratado = foco['estado_tratamiento'] == 'tratado';

                  return Marker(
                    point: LatLng(lat, lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _focoSeleccionado = foco;
                        });
                        _mapController.move(LatLng(lat, lng), 16.0);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: tratado
                              ? const Color(0xFF2D7A2D)
                              : const Color(0xFFC62828),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          tratado
                              ? Icons.check_rounded
                              : Icons.warning_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // Contador flotante
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _soloPendientes
                        ? Icons.report_problem_rounded
                        : Icons.layers_rounded,
                    size: 16,
                    color: _soloPendientes
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2D7A2D),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${focos.length} focos en mapa',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Ficha detalle flotante
          if (_focoSeleccionado != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: _buildTarjetaDetalle(_focoSeleccionado!),
            ),
        ],
      ),
    );
  }

  Widget _buildTarjetaDetalle(Map<String, dynamic> foco) {
    final diag = foco['diagnostico_principal'] ?? 'Afección detectada';
    final tratado = foco['estado_tratamiento'] == 'tratado';
    final autor = foco['usuario_nombre'] ?? 'Cuadrilla';
    final lat = (foco['latitud'] as num).toDouble();
    final lng = (foco['longitud'] as num).toDouble();
    final imageUrl = foco['image_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFF1F8F1),
                      child: const Icon(Icons.broken_image_rounded, size: 24),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diag,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reportado por: $autor',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A5D4A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => setState(() => _focoSeleccionado = null),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tratado
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tratado
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      size: 14,
                      color: tratado
                          ? const Color(0xFF2D7A2D)
                          : const Color(0xFFC62828),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tratado ? 'Tratada en campo' : 'Pendiente de tratamiento',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tratado
                            ? const Color(0xFF2D7A2D)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A2D),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => _abrirEnGoogleMaps(lat, lng),
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text('Cómo llegar', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
