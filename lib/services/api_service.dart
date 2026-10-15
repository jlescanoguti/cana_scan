import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl =
      'https://api-sugarcane-production-a2ee.up.railway.app';

  static Future<Map<String, dynamic>> predict(File imageFile) async {
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
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}