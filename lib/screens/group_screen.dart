import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class GroupScreen extends StatefulWidget {
  final bool embedded;
  const GroupScreen({super.key, this.embedded = false});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  bool _cargando = true;
  Map<String, dynamic>? _miGrupo;
  List<Map<String, dynamic>> _miembros = [];
  List<Map<String, dynamic>> _misGruposLider = [];

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

      List<Map<String, dynamic>> misGrupos = [];
      if (SupabaseService.currentRol == 'lider' ||
          (grupo != null &&
              grupo['lider_id'] == SupabaseService.currentUser?.id)) {
        misGrupos = await SupabaseService.getMisGruposComoLider();
      }

      if (mounted) {
        setState(() {
          _miGrupo = grupo;
          _miembros = miembros;
          _misGruposLider = misGrupos;
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

  Future<void> _cambiarGrupoActivo(String grupoId) async {
    setState(() => _procesandoAccion = true);
    try {
      await SupabaseService.seleccionarGrupoActivo(grupoId);
      await _cargarDatosGrupo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuadrilla activa cambiada con éxito'),
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

  void _mostrarDialogoCrearOtroGrupo() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Crear otra Cuadrilla',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Como Líder puedes gestionar múltiples cuadrillas independientes.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'ej: Finca Santa Rosa - Lote 4',
                prefixIcon: const Icon(Icons.business_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF9FBF9),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF6B806B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D7A2D),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nombre = controller.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _procesandoAccion = true);
              try {
                await SupabaseService.crearGrupo(nombre);
                await _cargarDatosGrupo();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Nueva cuadrilla creada con éxito!'),
                      backgroundColor: Color(0xFF2D7A2D),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: const Color(0xFFC62828)),
                  );
                }
              } finally {
                if (mounted) setState(() => _procesandoAccion = false);
              }
            },
            child: const Text('Crear Cuadrilla'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarSalirGrupo() async {
    if (_miGrupo == null) return;

    final esLider = _miGrupo!['lider_id'] == SupabaseService.currentUser?.id;
    final otrosMiembros = _miembros
        .where((m) => m['id'] != SupabaseService.currentUser?.id)
        .toList();

    if (esLider) {
      if (otrosMiembros.isEmpty) {
        // Líder es el único integrante: disolver
        await _confirmarDisolverCuadrilla();
      } else {
        // Líder con otros trabajadores: ofrecer transferir o disolver
        _mostrarOpcionesSalidaLider(otrosMiembros);
      }
      return;
    }

    // Empleado normal saliendo
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
      setState(() => _procesandoAccion = true);
      try {
        await SupabaseService.salirDeGrupo();
        await _cargarDatosGrupo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Has salido de la cuadrilla.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al salir: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _procesandoAccion = false);
      }
    }
  }

  void _mostrarOpcionesSalidaLider(List<Map<String, dynamic>> otrosMiembros) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Color(0xFFC62828), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gestión de salida del Líder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A1B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Eres el creador y líder de «${_miGrupo?['nombre']}». Para salir, debes designar a un sucesor o disolver la cuadrilla.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFC8E6C9)),
                ),
                tileColor: const Color(0xFFF1F8F1),
                leading: const Icon(Icons.swap_horiz_rounded,
                    color: Color(0xFF2D7A2D)),
                title: const Text('Transferir liderazgo y salir',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A1B))),
                subtitle: Text(
                  'Elige a uno de los ${otrosMiembros.length} trabajadores como nuevo líder.',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF4A5D4A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _mostrarDialogoTransferirLiderazgo(otrosMiembros);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                ),
                tileColor: const Color(0xFFFFF5F5),
                leading: const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFC62828)),
                title: const Text('Disolver cuadrilla por completo',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFC62828))),
                subtitle: const Text(
                  'Desvincula a todos los miembros y elimina el grupo permanentemente.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7A4A4A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarDisolverCuadrilla();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoTransferirLiderazgo(
      List<Map<String, dynamic>> otrosMiembros) async {
    String? seleccionadoId = otrosMiembros.first['id'];

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Designar nuevo líder',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona al trabajador que asumirá la administración y gestión de esta cuadrilla:',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF4A5D4A)),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: otrosMiembros.length,
                    itemBuilder: (context, i) {
                      final m = otrosMiembros[i];
                      final id = m['id'] as String;
                      final nombre = m['nombre_completo'] ?? 'Trabajador';
                      final dni = m['dni'] ?? '';
                      final isSelected = seleccionadoId == id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFE8F5E9)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2D7A2D)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setDialogState(() => seleccionadoId = id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? const Color(0xFF2D7A2D)
                                      : const Color(0xFF8BA08B),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 13,
                                          color: const Color(0xFF1B3A1B),
                                        ),
                                      ),
                                      Text(
                                        'DNI: $dni',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B806B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF6B806B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: seleccionadoId == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Transferir y salir'),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true && seleccionadoId != null && _miGrupo != null) {
      setState(() => _procesandoAccion = true);
      try {
        await SupabaseService.transferirLiderazgoYSalir(
            _miGrupo!['id'], seleccionadoId!);
        await _cargarDatosGrupo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Liderazgo transferido exitosamente. Has salido del grupo.'),
              backgroundColor: Color(0xFF2D7A2D),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al transferir liderazgo: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _procesandoAccion = false);
      }
    }
  }

  Future<void> _confirmarDisolverCuadrilla() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Disolver cuadrilla?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Esta acción es definitiva. Se eliminará la cuadrilla «${_miGrupo?['nombre']}» y todos sus miembros quedarán desvinculados.',
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
            child: const Text('Disolver definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar == true && _miGrupo != null) {
      setState(() => _procesandoAccion = true);
      try {
        await SupabaseService.disolverCuadrilla(_miGrupo!['id']);
        await _cargarDatosGrupo();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La cuadrilla ha sido disuelta.'),
              backgroundColor: Color(0xFF2D7A2D),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al disolver cuadrilla: $e'),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _procesandoAccion = false);
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
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Color(0xFF1B3A1B)),
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

  Widget _buildSelectorCuadrillasLider() {
    if (_misGruposLider.isEmpty) return const SizedBox.shrink();

    final idActivo = _miGrupo?['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E5D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.hub_rounded, color: Color(0xFF2D7A2D), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Mis Cuadrillas como Líder',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed:
                    _procesandoAccion ? null : _mostrarDialogoCrearOtroGrupo,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Nueva'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2D7A2D),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: _misGruposLider.map((g) {
              final esActivo = g['id'] == idActivo;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: esActivo
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFF9FBF9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: esActivo
                        ? const Color(0xFF2D7A2D)
                        : const Color(0xFFE0E0E0),
                    width: esActivo ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  leading: Icon(
                    esActivo
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: esActivo
                        ? const Color(0xFF2D7A2D)
                        : const Color(0xFF8D998D),
                  ),
                  title: Text(
                    g['nombre'] ?? 'Cuadrilla',
                    style: TextStyle(
                      fontWeight: esActivo ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                      color: const Color(0xFF1B3A1B),
                    ),
                  ),
                  subtitle: Text(
                    'Código: ${g['codigo_invitacion'] ?? ''}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF6B806B)),
                  ),
                  trailing: esActivo
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D7A2D),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Activa',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        )
                      : TextButton(
                          onPressed: _procesandoAccion
                              ? null
                              : () => _cambiarGrupoActivo(g['id']),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2D7A2D),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          child: const Text('Activar',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVistaSinGrupo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_misGruposLider.isNotEmpty) _buildSelectorCuadrillasLider(),
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
        if (esLider || _misGruposLider.isNotEmpty)
          _buildSelectorCuadrillasLider(),
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
