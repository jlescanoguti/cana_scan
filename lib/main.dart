import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const CanaScanApp());
}

class CanaScanApp extends StatelessWidget {
  const CanaScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CañaScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7A2D),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}