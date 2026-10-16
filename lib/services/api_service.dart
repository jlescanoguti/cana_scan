import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl =
      'https://api-sugarcane-production.up.railway.app';

  /// Realiza el diagnóstico del cultivo enviando la imagen a la API de Railway.
  static Future<Map<String, dynamic>> predict(File imageFile) async {
    try {
      final uri = Uri.parse('$baseUrl/predict');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            'El servidor de Railway respondió con error (${response.statusCode}): ${response.body}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet o el servidor de Railway no está accesible.');
    } catch (e) {
      throw Exception('Error en el diagnóstico: $e');
    }
  }
}