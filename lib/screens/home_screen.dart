import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';
import '../widgets/app_info_sheet.dart';
import 'group_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceTab = 0;
  Map<String, dynamic>? _miGrupo;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    if (!SupabaseService.isAuthenticated) return;

    await SupabaseService.loadProfile();
    final grupo = await SupabaseService.getMiGrupo();
    if (mounted) {
      setState(() {
        _miGrupo = grupo;
      });
    }
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (picked != null && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            imageFile: File(picked.path),
            isFromGallery: source == ImageSource.gallery,
          ),
        ),
      );
      // Al volver, refrescar estado por si se actualizó el grupo
      _cargarDatosUsuario();
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Cerrar sesión?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text(
          'Tendrás que volver a ingresar con tu DNI y PIN para acceder a tus diagnósticos.',
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await SupabaseService.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final autenticado = SupabaseService.isAuthenticated;
    final nombre = SupabaseService.currentNombre;
    final rol = SupabaseService.currentRol;
    final nombreGrupo = _miGrupo?['nombre'];

    Widget cuerpo;
    switch (_indiceTab) {
      case 1:
        cuerpo = autenticado
            ? const HistoryScreen(embedded: true)
            : _buildInvitadoPlaceholder(
                icon: Icons.history_rounded,
                titulo: 'Historial de Diagnósticos',
                mensaje:
                    'Inicia sesión con tu DNI para guardar y revisar el historial de detecciones de tus parcelas.',
              );
        break;
      case 2:
        cuerpo = autenticado
            ? const GroupScreen(embedded: true)
            : _buildInvitadoPlaceholder(
                icon: Icons.groups_rounded,
                titulo: 'Cuadrilla de Trabajo',
                mensaje:
                    'Inicia sesión con tu DNI para unirte a una cuadrilla o coordinar labores con tu equipo en campo.',
              );
        break;
      case 0:
      default:
        cuerpo = _buildVistaEscanear(
          autenticado: autenticado,
          nombre: nombre,
          rol: rol,
          nombreGrupo: nombreGrupo,
        );
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F1),
      body: cuerpo,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _indiceTab == 0
          ? FloatingActionButton(
              heroTag: 'infoButton',
              onPressed: () => AppInfoSheet.show(context),
              backgroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(
                side: BorderSide(color: Color(0xFFD7E5D7), width: 1),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF2D7A2D),
                size: 26,
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceTab,
        onDestinationSelected: (idx) {
          setState(() => _indiceTab = idx);
          if (idx != 0 && SupabaseService.isAuthenticated) {
            _cargarDatosUsuario();
          }
        },
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: const Color(0xFFE8F5E9),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.document_scanner_outlined, color: Color(0xFF6B806B)),
            selectedIcon:
                Icon(Icons.document_scanner_rounded, color: Color(0xFF2D7A2D)),
            label: 'Escanear',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined, color: Color(0xFF6B806B)),
            selectedIcon:
                Icon(Icons.history_rounded, color: Color(0xFF2D7A2D)),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined, color: Color(0xFF6B806B)),
            selectedIcon:
                Icon(Icons.groups_rounded, color: Color(0xFF2D7A2D)),
            label: 'Cuadrilla',
          ),
        ],
      ),
    );
  }

  Widget _buildVistaEscanear({
    required bool autenticado,
    required String nombre,
    required String rol,
    required String? nombreGrupo,
  }) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Barra superior limpia
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7A2D),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D7A2D).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CañaScan',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B3A1B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Diagnóstico en campo',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B806B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                if (!autenticado) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D7A2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      _cargarDatosUsuario();
                    },
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Acceder',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ] else ...[
                  // Chip compacto con usuario y rol + botón salir discreto
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFD7E5D7), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: const Color(0xFFE8F5E9),
                          child: Text(
                            nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2D7A2D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 85),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nombre.split(' ').first,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1B3A1B),
                                ),
                              ),
                              Text(
                                rol == 'lider' ? 'Líder' : 'Empleado',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D7A2D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 17,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.logout_rounded,
                              color: Color(0xFFC62828)),
                          tooltip: 'Cerrar sesión',
                          onPressed: () => _confirmSignOut(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Chip de estado / cuadrilla activa
            if (autenticado && nombreGrupo != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFD7E5D7), width: 0.8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hub_rounded,
                        size: 16, color: Color(0xFF2D7A2D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cuadrilla activa: $nombreGrupo',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B3A1B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'Diagnostica tu cultivo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5D4A),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Captura una hoja para empezar',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B3A1B),
                height: 1.15,
              ),
            ),

            const SizedBox(height: 20),

            _buildActionCard(
              title: 'Tomar foto',
              subtitle: 'Usa la cámara para capturar la hoja en campo',
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFF2D7A2D),
              onTap: () => _pickImage(context, ImageSource.camera),
            ),

            const SizedBox(height: 12),

            _buildActionCard(
              title: 'Galería',
              subtitle: 'Selecciona una imagen guardada en tu teléfono',
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF1B3A1B),
              onTap: () => _pickImage(context, ImageSource.gallery),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitadoPlaceholder({
    required IconData icon,
    required String titulo,
    required String mensaje,
  }) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: const Color(0xFF2D7A2D)),
              ),
              const SizedBox(height: 20),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B3A1B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A5D4A),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A2D),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  _cargarDatosUsuario();
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('Iniciar Sesión',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD7E5D7),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4A5D4A),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFA0B0A0),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}