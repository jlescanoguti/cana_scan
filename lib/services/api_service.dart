import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'yolo_service.dart';

class ApiService {
  static const String baseUrl =
      'https://api-sugarcane-production-a2ee.up.railway.app';

  /// Realiza el diagnóstico del cultivo.
  /// Prioridad 1: Inferencia local en el dispositivo (Edge AI, 100% offline y ultra rápido).
  /// Prioridad 2: Respaldo por API remota si los modelos locales aún no se cargaron.
  static Future<Map<String, dynamic>> predict(File imageFile) async {
    // 1. Intentar inferencia local en el teléfono
    try {
      final ready = await YoloService.initialize();
      if (ready) {
        return await YoloService.predict(imageFile);
      }
    } catch (_) {
      // Si los archivos locales no están en assets/models/, continúa al fallback remoto
    }

    // 2. Respaldo por red
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('El servidor de Railway respondió con error: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Coloca los modelos locales en assets/models/ para diagnosticar sin conexión.');
    } catch (e) {
      throw Exception('Error en el diagnóstico: $e');
    }
  }
}