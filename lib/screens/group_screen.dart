import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  bool _cargando = true;
  Map<String, dynamic>? _miGrupo;
  List<Map<String, dynamic>> _miembros = [];

  final _codigoController = TextEditingController();
  final _nombreGrupoController = TextEditingController();
  bool _procesandoAccion = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosGrupo();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreGrupoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosGrupo() async {
    setState(() {
      _cargando = true;
    });

    try {
      final grupo = await SupabaseService.getMiGrupo();
      List<Map<String, dynamic>> miembros = [];
      if (grupo != null) {
        miembros = await SupabaseService.getMiembrosGrupo(grupo['id']);
      }

      if (mounted) {
        setState(() {
          _miGrupo = grupo;
          _miembros = miembros;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<void> _unirseAGrupo() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) return;

    setState(() => _procesandoAccion = true);

    try {
      await SupabaseService.unirseAGrupo(codigo);
      _codigoController.clear();
      await _cargarDatosGrupo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Te has unido a la cuadrilla con éxito!'),
            backgroundColor: Color(0xFF2D7A2D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoAccion = false);
    }
  }

  Future<void> _crearGrupo() async {
    final nombre = _nombreGrupoController.text.trim();
    if (nombre.isEmpty) return;

    setState(() => _procesandoAccion = true);

    try {
      await SupabaseService.crearGrupo(nombre);
      _nombreGrupoController.clear();
      await _cargarDatosGrupo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuadrilla creada con éxito! Eres el Líder.'),
            backgroundColor: Color(0xFF2D7A2D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoAccion = false);
    }
  }

  Future<void> _confirmarSalirGrupo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Salir de esta cuadrilla?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
          'Dejarás de compartir tus detecciones con este equipo. Los reportes que ya hiciste permanecerán en la finca.',
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
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await SupabaseService.salirDeGrupo();
      await _cargarDatosGrupo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Has salido de la cuadrilla.')),
        );
      }
    }
  }

  Future<void> _confirmarRemoverMiembro(String usuarioId, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Remover trabajador?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          '¿Deseas desvincular a $nombre de la cuadrilla?',
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
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await SupabaseService.removerMiembro(usuarioId);
      await _cargarDatosGrupo();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Mi Cuadrilla de Trabajo',
          style: TextStyle(
            color: Color(0xFF1B3A1B),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D7A2D)),
            )
          : RefreshIndicator(
              color: const Color(0xFF2D7A2D),
              onRefresh: _cargarDatosGrupo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _miGrupo == null
                    ? _buildVistaSinGrupo()
                    : _buildVistaConGrupo(),
              ),
            ),
    );
  }

  Widget _buildVistaSinGrupo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7E5D7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_add_rounded,
                      color: Color(0xFF2D7A2D), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Unirme a una Cuadrilla existente',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa el código de 6 caracteres que te proporcionó tu Líder o capataz.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _codigoController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'ej: CANA-784',
                  prefixIcon: const Icon(Icons.key_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7A2D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _procesandoAccion ? null : _unirseAGrupo,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Unirme a la Cuadrilla'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD7E5D7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: Color(0xFF1B3A1B), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Crear una nueva Cuadrilla',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Si eres responsable o capataz de campo, crea la cuadrilla para que tus trabajadores se unan.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nombreGrupoController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'ej: Finca Santa Rosa - Lote 3',
                  prefixIcon: const Icon(Icons.business_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF9FBF9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1B3A1B),
                    side: const BorderSide(color: Color(0xFF1B3A1B)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _procesandoAccion ? null : _crearGrupo,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Crear Cuadrilla y ser Líder'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVistaConGrupo() {
    final esLider = SupabaseService.currentRol == 'lider';
    final codigo = _miGrupo!['codigo_invitacion'] ?? '';
    final nombreGrupo = _miGrupo!['nombre'] ?? '';
    final liderNombre = _miGrupo!['lider_nombre'] ?? 'Líder';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tarjeta Cabecera
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF2D7A2D),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      nombreGrupo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      esLider ? 'Líder' : 'Empleado',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Responsable: $liderNombre',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Código de invitación:',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        codigo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2D7A2D),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codigo));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Código copiado al portapapeles'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Lista de Miembros
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Integrantes de la cuadrilla',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B3A1B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_miembros.length} personas',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D7A2D),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _miembros.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final m = _miembros[index];
            final esMiembroLider = m['rol'] == 'lider';
            final esMismoUsuario =
                m['id'] == SupabaseService.currentUser?.id;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD7E5D7)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: esMiembroLider
                        ? const Color(0xFF2D7A2D)
                        : const Color(0xFFE8F5E9),
                    foregroundColor:
                        esMiembroLider ? Colors.white : const Color(0xFF2D7A2D),
                    child: Icon(
                      esMiembroLider
                          ? Icons.star_rounded
                          : Icons.person_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['nombre_completo'] ?? 'Trabajador',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        Text(
                          'DNI: ${m['dni'] ?? ''} ${esMismoUsuario ? '(Tú)' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B806B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (esLider && !esMismoUsuario)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: Color(0xFFC62828), size: 20),
                      tooltip: 'Remover de la cuadrilla',
                      onPressed: () => _confirmarRemoverMiembro(
                        m['id'],
                        m['nombre_completo'] ?? 'el trabajador',
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 32),

        // Botón Salir de la Cuadrilla
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _confirmarSalirGrupo,
            icon: const Icon(Icons.exit_to_app_rounded),
            label: const Text(
              'Salir de esta cuadrilla',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
