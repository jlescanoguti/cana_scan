import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import 'map_screen.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _cargando = true;
  List<Map<String, dynamic>> _historialGrupal = [];
  List<Map<String, dynamic>> _historialPersonal = [];
  String? _error;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    final tieneGrupo = SupabaseService.currentGrupoId != null;
    if (tieneGrupo) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _cargarHistorial();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _cargarHistorial() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final grupoId = SupabaseService.currentGrupoId;
      List<Map<String, dynamic>> grupal = [];
      if (grupoId != null) {
        grupal = await SupabaseService.getGroupHistory(grupoId);
      }
      final personal = await SupabaseService.getPersonalHistory();

      if (mounted) {
        setState(() {
          _historialGrupal = grupal;
          _historialPersonal = personal;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo cargar el historial: $e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _abrirEnGoogleMaps(double lat, double lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _cambiarEstadoTratamiento(
      String id, String nuevoEstado, String accion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿$accion?',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Text(
          nuevoEstado == 'tratado'
              ? 'Se registrará que este foco ya recibió tratamiento fitosanitario en campo.'
              : 'Se marcará como descarte o falsa alarma.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF4A5D4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B806B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nuevoEstado == 'tratado'
                  ? const Color(0xFF2D7A2D)
                  : const Color(0xFF5F5E5A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(accion),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final ok = await SupabaseService.actualizarEstadoTratamiento(
        scanId: id,
        nuevoEstado: nuevoEstado,
      );
      if (ok) {
        await _cargarHistorial();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Estado actualizado a: $nuevoEstado')),
          );
        }
      }
    }
  }

  Future<void> _eliminarRegistro(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar diagnóstico?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text(
          'Esta acción no se puede deshacer y borrará el registro de tu historial.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4A5D4A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B806B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final ok = await SupabaseService.deleteHistoryRecord(id);
      if (ok && mounted) {
        setState(() {
          _historialGrupal.removeWhere((item) => item['id'] == id);
          _historialPersonal.removeWhere((item) => item['id'] == id);
        });
      }
    }
  }

  String _formatearFecha(String? fechaIso) {
    if (fechaIso == null) return '';
    try {
      final date = DateTime.parse(fechaIso).toLocal();
      final meses = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final mes = meses[date.month - 1];
      final hora = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '${date.day} $mes ${date.year}, $hora:$min';
    } catch (_) {
      return fechaIso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tieneGrupo = SupabaseService.currentGrupoId != null;
    final focosConGps = (tieneGrupo ? _historialGrupal : _historialPersonal)
        .where((e) => e['latitud'] != null && e['longitud'] != null)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F8F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B3A1B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Historial de Diagnósticos',
          style: TextStyle(
            color: Color(0xFF1B3A1B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: tieneGrupo && _tabController != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF2D7A2D),
                labelColor: const Color(0xFF2D7A2D),
                unselectedLabelColor: const Color(0xFF6B806B),
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Mi Cuadrilla'),
                  Tab(text: 'Mis Escaneos'),
                ],
              )
            : null,
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D7A2D)),
            )
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFC62828))),
                )
              : tieneGrupo && _tabController != null
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLista(_historialGrupal, esGrupal: true),
                        _buildLista(_historialPersonal, esGrupal: false),
                      ],
                    )
                  : _buildLista(_historialPersonal, esGrupal: false),
      floatingActionButton: focosConGps.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF2D7A2D),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(
                      escaneos: tieneGrupo
                          ? _historialGrupal
                          : _historialPersonal,
                      titulo: tieneGrupo
                          ? 'Mapa de la Cuadrilla'
                          : 'Mapa de mis Focos',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Ver Mapa'),
            )
          : null,
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> items,
      {required bool esGrupal}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded,
                size: 64, color: Color(0xFFA0B0A0)),
            const SizedBox(height: 12),
            Text(
              esGrupal
                  ? 'Aún no hay reportes en la cuadrilla'
                  : 'Aún no has registrado diagnósticos',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5D4A),
              ),
            ),
          ],
        ),
      );
    }

    final esLider = SupabaseService.currentRol == 'lider';

    return RefreshIndicator(
      color: const Color(0xFF2D7A2D),
      onRefresh: _cargarHistorial,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          final diag = item['diagnostico_principal'] ?? 'No reconocido';
          final estado = item['estado_general'] ?? 'no_reconocido';
          final tratamiento = item['estado_tratamiento'] ?? 'pendiente';
          final fecha = _formatearFecha(item['created_at']);
          final autor = item['usuario_nombre'] ?? 'Tú';
          final imageUrl = item['image_url'] as String?;
          final lat = item['latitud'] as num?;
          final lng = item['longitud'] as num?;
          final esAfeccion = estado == 'afeccion';
          final esPropio = item['user_id'] == SupabaseService.currentUser?.id;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD7E5D7), width: 0.6),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(
                      imageUrl: imageUrl,
                      initialResult: item,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Miniatura
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: (imageUrl != null && imageUrl.isNotEmpty)
                              ? Image.network(
                                  imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFF1F8F1),
                                    child: const Icon(
                                        Icons.broken_image_rounded,
                                        size: 24),
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFFF1F8F1),
                                  child: const Icon(Icons.image_outlined,
                                      size: 24),
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B3A1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fecha,
                                style: const TextStyle(
                                    fontSize: 11.5, color: Color(0xFF6B806B)),
                              ),
                              if (esGrupal) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Registrado por: $autor',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D7A2D)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (esPropio)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFC62828), size: 20),
                            onPressed: () => _eliminarRegistro(item['id']),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Badges de estado y GPS
                    Row(
                      children: [
                        if (esAfeccion) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tratamiento == 'tratado'
                                  ? const Color(0xFFE8F5E9)
                                  : tratamiento == 'descartado'
                                      ? const Color(0xFFF1EFE8)
                                      : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tratamiento == 'tratado'
                                      ? Icons.check_circle_rounded
                                      : tratamiento == 'descartado'
                                          ? Icons.cancel_outlined
                                          : Icons.warning_rounded,
                                  size: 13,
                                  color: tratamiento == 'tratado'
                                      ? const Color(0xFF2D7A2D)
                                      : tratamiento == 'descartado'
                                          ? const Color(0xFF5F5E5A)
                                          : const Color(0xFFC62828),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tratamiento == 'tratado'
                                      ? 'Tratada en campo'
                                      : tratamiento == 'descartado'
                                          ? 'Falsa alarma'
                                          : 'Pendiente de tratamiento',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: tratamiento == 'tratado'
                                        ? const Color(0xFF2D7A2D)
                                        : tratamiento == 'descartado'
                                            ? const Color(0xFF5F5E5A)
                                            : const Color(0xFFC62828),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        if (lat != null && lng != null)
                          ActionChip(
                            avatar: const Icon(Icons.near_me_rounded,
                                size: 14, color: Color(0xFF2D7A2D)),
                            label: const Text('Ver en Maps',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFF1F8F1),
                            padding: EdgeInsets.zero,
                            onPressed: () => _abrirEnGoogleMaps(
                                lat.toDouble(), lng.toDouble()),
                          ),
                      ],
                    ),

                    // Acciones de gestión para el Líder si está pendiente
                    if (esLider && esAfeccion && tratamiento == 'pendiente') ...[
                      const Divider(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5F5E5A),
                            ),
                            onPressed: () => _cambiarEstadoTratamiento(
                                item['id'], 'descartado', 'Descartar reporte'),
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Descartar',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D7A2D),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _cambiarEstadoTratamiento(
                                item['id'], 'tratado', 'Marcar como tratada'),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Marcar tratada',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
