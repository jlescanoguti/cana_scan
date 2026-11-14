import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Duración mínima de la pantalla de bienvenida
  static const _duracionMinima = Duration(milliseconds: 1200);

  late final AnimationController _progreso = AnimationController(
    vsync: this,
    duration: _duracionMinima,
  )..forward();

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  @override
  void dispose() {
    _progreso.dispose();
    super.dispose();
  }

  Future<void> _startLoading() async {
    // El perfil se carga mientras corre la animación
    await Future.wait([
      Future.delayed(_duracionMinima),
      _cargarPerfil(),
    ]);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _cargarPerfil() async {
    if (!SupabaseService.isAuthenticated) return;
    try {
      await SupabaseService.loadProfile();
    } catch (_) {
      // Sin conexión: Home volverá a intentarlo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '🌿',
                  style: TextStyle(fontSize: 42),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'CañaScan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Diagnóstico foliar inteligente',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 160,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: AnimatedBuilder(
                  animation: _progreso,
                  builder: (context, _) => LinearProgressIndicator(
                    value: _progreso.value,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF66BB6A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}