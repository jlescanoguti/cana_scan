import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cliente de la API de diagnóstico en Railway. La app siempre diagnostica
/// mediante esta API, por lo que requiere conexión a internet.
class ApiService {
  static const String baseUrl =
      'https://api-sugarcane-production.up.railway.app';

  static const Duration _timeout = Duration(seconds: 45);

  /// Envía la imagen a la API y devuelve el diagnóstico.
  /// Lanza un `String` con un mensaje listo para mostrar si algo falla.
  static Future<Map<String, dynamic>> predict(File imageFile) async {
    final http.Response response;
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/predict'))
            ..files.add(
                await http.MultipartFile.fromPath('file', imageFile.path));

      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on SocketException {
      throw 'Sin conexión a internet. Conéctate para analizar la hoja.';
    } on TimeoutException {
      throw 'El servidor tardó demasiado en responder. Inténtalo de nuevo.';
    } on http.ClientException {
      throw 'No se pudo conectar con el servidor de diagnóstico.';
    } on FileSystemException {
      throw 'No se pudo leer la foto. Vuelve a tomarla o elígela de la galería.';
    }

    if (response.statusCode >= 500) {
      throw 'El servidor de diagnóstico no está disponible en este momento '
          '(código ${response.statusCode}). Inténtalo más tarde.';
    }
    if (response.statusCode != 200) {
      throw 'El servidor no pudo analizar la imagen (código ${response.statusCode}). '
          'Intenta con otra foto.';
    }

    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return Map<String, dynamic>.from(data as Map);
    } catch (_) {
      throw 'La respuesta del servidor no es válida.';
    }
  }
}
