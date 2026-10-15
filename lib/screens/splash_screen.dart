import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() async {
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 25));
      if (mounted) {
        setState(() {
          _progress = i / 100;
        });
      }
    }
    if (mounted) {
      if (SupabaseService.isAuthenticated) {
        await SupabaseService.loadProfile();
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
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
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF66BB6A),
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