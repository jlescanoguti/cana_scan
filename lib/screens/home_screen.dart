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
        setState(() {
          _miGrupo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final autenticado = SupabaseService.isAuthenticated;
    final nombre = SupabaseService.currentNombre;
    final rol = SupabaseService.currentRol;
    final nombreGrupo = _miGrupo?['nombre'];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Barra superior
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D7A2D),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2D7A2D).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🌿', style: TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CañaScan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B3A1B),
                        ),
                      ),
                      Text(
                        'Diagnóstico en campo',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF6B806B)),
                      ),
                    ],
                  ),
                  const Spacer(),

                  if (!autenticado) ...[
                    // Botón para acceder
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
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                        _cargarDatosUsuario();
                      },
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: const Text('Acceder',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ] else ...[
                    // Botón Cuadrilla / Grupo
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFD7E5D7), width: 0.6),
                      ),
                      child: IconButton(
                        tooltip: 'Mi Cuadrilla',
                        icon: const Icon(Icons.groups_rounded,
                            color: Color(0xFF2D7A2D), size: 22),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GroupScreen()),
                          );
                          _cargarDatosUsuario();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Historial
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFD7E5D7), width: 0.6),
                      ),
                      child: IconButton(
                        tooltip: 'Historial',
                        icon: const Icon(Icons.history_rounded,
                            color: Color(0xFF2D7A2D), size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botón Salir
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFD7E5D7), width: 0.6),
                      ),
                      child: IconButton(
                        tooltip: 'Cerrar sesión',
                        icon: const Icon(Icons.logout_rounded,
                            color: Color(0xFFC62828), size: 18),
                        onPressed: () => _confirmSignOut(context),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              // Banner de Usuario o de Invitado
              if (autenticado) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFD7E5D7), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE8F5E9),
                        foregroundColor: const Color(0xFF2D7A2D),
                        radius: 20,
                        child: const Icon(Icons.person_rounded, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B3A1B),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  rol == 'lider'
                                      ? 'Líder de Cuadrilla'
                                      : 'Trabajador',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D7A2D)),
                                ),
                                if (nombreGrupo != null) ...[
                                  const Text(' · ',
                                      style:
                                          TextStyle(color: Color(0xFF6B806B))),
                                  Expanded(
                                    child: Text(
                                      nombreGrupo,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF4A5D4A)),
                                    ),
                                  ),
                                ] else ...[
                                  const Text(' · Sin cuadrilla',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF6B806B))),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Color(0xFF2D7A2D), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Modo Invitado: puedes escanear libremente. Inicia sesión con DNI para guardar en tu cuadrilla.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1B3A1B),
                              height: 1.3),
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
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
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