class DniResult {
  final String dni;
  final String nombreCompleto;
  final bool existe;

  const DniResult({
    required this.dni,
    required this.nombreCompleto,
    required this.existe,
  });
}

class DniService {
  /// Valida la estructura básica del DNI (8 dígitos numéricos exactos)
  static String? validarFormatoDni(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu número de DNI';
    }
    final clean = value.trim();
    if (!RegExp(r'^\d{8}$').hasMatch(clean)) {
      return 'El DNI debe tener exactamente 8 números';
    }
    return null;
  }

  /// Consulta el DNI. Actualmente implementa el Nivel 1 (validación de formato).
  /// Está preparado para conectar la API de Factiliza en el futuro sin modificar la UI.
  static Future<DniResult?> consultarDni(String dni) async {
    final cleanDni = dni.trim();
    if (validarFormatoDni(cleanDni) != null) return null;

    // TODO: En Fase 2 (Nivel 2), aquí se conectará la API de Factiliza:
    // final response = await http.get(
    //   Uri.parse('https://api.factiliza.com/v1/dni/$cleanDni'),
    //   headers: {'Authorization': 'Bearer $TOKEN_FACTILIZA'},
    // );
    // if (response.statusCode == 200) { ... }

    return DniResult(
      dni: cleanDni,
      nombreCompleto: '',
      existe: true,
    );
  }
}
