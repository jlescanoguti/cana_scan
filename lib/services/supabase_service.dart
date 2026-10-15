import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://rdrcnsiwxuxzuuvdgysu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkcmNuc2l3eHV4enV1dmRneXN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5NDY3NjksImV4cCI6MjEwNTUyMjc2OX0.KvEmVYn7aJJvpJ93oK8aevkwii5hBTOklVdElylXZHU';

  /// Perfil del usuario activo en memoria
  static Map<String, dynamic>? _currentProfile;

  /// Inicializa Supabase antes de arrancar la aplicación
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  /// Instancia del cliente de Supabase
  static SupabaseClient get client => Supabase.instance.client;

  /// Usuario actualmente autenticado (o null si es modo invitado)
  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Indica si hay una sesión activa de usuario
  static bool get isAuthenticated => currentUser != null;

  /// Perfil cargado en memoria
  static Map<String, dynamic>? get currentProfile => _currentProfile;

  /// Nombre del usuario actual
  static String get currentNombre {
    if (_currentProfile != null && _currentProfile!['nombre_completo'] != null) {
      return _currentProfile!['nombre_completo'].toString();
    }
    return 'Agricultor';
  }

  /// Rol del usuario ('lider' o 'empleado')
  static String get currentRol {
    if (_currentProfile != null && _currentProfile!['rol'] != null) {
      return _currentProfile!['rol'].toString();
    }
    return 'empleado';
  }

  /// ID del grupo actual del usuario (o null si es independiente)
  static String? get currentGrupoId {
    if (_currentProfile != null && _currentProfile!['grupo_id'] != null) {
      return _currentProfile!['grupo_id'].toString();
    }
    return null;
  }

  /// Mapea un DNI a un email seguro interno de Supabase
  static String dniToEmail(String dni) {
    return '${dni.trim()}@canascan.app';
  }

  /// Mapea un PIN numérico a una contraseña segura interna
  static String pinToPassword(String pin) {
    return 'pin_${pin.trim()}';
  }

  // ========================================================================
  // AUTENTICACIÓN Y PERFIL
  // ========================================================================

  /// Registra una nueva cuenta por DNI + PIN + Datos de auxilio
  static Future<AuthResponse> signUp({
    required String dni,
    required String nombreCompleto,
    required String pin,
    required String preguntaAuxilio,
    required String respuestaAuxilio,
  }) async {
    try {
      final cleanDni = dni.trim();
      final email = dniToEmail(cleanDni);
      final password = pinToPassword(pin);

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'dni': cleanDni, 'nombre': nombreCompleto.trim()},
      );

      final user = response.user;
      if (user != null) {
        // Insertar en la tabla perfiles
        await client.from('perfiles').insert({
          'id': user.id,
          'dni': cleanDni,
          'nombre_completo': nombreCompleto.trim(),
          'pregunta_auxilio': preguntaAuxilio.trim(),
          'respuesta_auxilio': respuestaAuxilio.trim().toLowerCase(),
          'rol': 'empleado',
          'grupo_id': null,
        });
      }

      return response;
    } on AuthException catch (e) {
      throw _traducirErrorAuth(e.message);
    } catch (e) {
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('perfiles_dni_key')) {
        throw 'Este DNI ya cuenta con una cuenta registrada.';
      }
      throw 'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
    }
  }

  /// Inicia sesión con DNI y PIN
  static Future<AuthResponse> signIn({
    required String dni,
    required String pin,
  }) async {
    try {
      final email = dniToEmail(dni);
      final password = pinToPassword(pin);

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Cargar perfil en memoria
      await loadProfile();
      return response;
    } on AuthException catch (e) {
      throw _traducirErrorAuth(e.message);
    } catch (_) {
      throw 'Error de conexión. Verifica tu señal de internet.';
    }
  }

  /// Carga el perfil del usuario activo en memoria
  static Future<Map<String, dynamic>?> loadProfile() async {
    final user = currentUser;
    if (user == null) {
      _currentProfile = null;
      return null;
    }

    try {
      final data = await client
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      _currentProfile = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Cierra la sesión activa
  static Future<void> signOut() async {
    _currentProfile = null;
    await client.auth.signOut();
  }

  /// Obtiene la pregunta de auxilio para un DNI (para recuperación de PIN)
  static Future<String?> getPreguntaAuxilio(String dni) async {
    try {
      final data = await client
          .from('perfiles')
          .select('pregunta_auxilio')
          .eq('dni', dni.trim())
          .maybeSingle();

      if (data != null && data['pregunta_auxilio'] != null) {
        return data['pregunta_auxilio'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Verifica la respuesta de auxilio y restablece el PIN
  static Future<bool> restablecerPinConAuxilio({
    required String dni,
    required String respuestaAuxilio,
    required String nuevoPin,
  }) async {
    try {
      final cleanDni = dni.trim();
      final data = await client
          .from('perfiles')
          .select('id, respuesta_auxilio')
          .eq('dni', cleanDni)
          .maybeSingle();

      if (data == null) throw 'DNI no encontrado';

      final respuestaGuardada = data['respuesta_auxilio']?.toString() ?? '';
      if (respuestaGuardada != respuestaAuxilio.trim().toLowerCase()) {
        throw 'La respuesta de auxilio no coincide.';
      }

      // Iniciar sesión temporal con credencial de servicio o actualizar contraseña
      // Si el usuario recuerda su respuesta, iniciamos sesión para actualizar password
      // Alternativa: Iniciar sesión temporal usando la función de Supabase
      // Para este caso, invocamos la actualización de usuario
      await client.rpc('restablecer_pin_usuario', params: {
        'p_dni': cleanDni,
        'p_respuesta': respuestaAuxilio.trim().toLowerCase(),
        'p_nuevo_password': pinToPassword(nuevoPin),
      });

      return true;
    } catch (e) {
      if (e.toString().contains('no coincide')) rethrow;
      throw 'No se pudo restablecer el PIN. Inténtalo más tarde.';
    }
  }

  // ========================================================================
  // GESTIÓN DE CUADRILLAS / GRUPOS DE TRABAJO
  // ========================================================================

  /// Genera un código de invitación aleatorio (ej: CANA-784)
  static String _generarCodigoGrupo() {
    final random = Random();
    final numero = random.nextInt(900) + 100;
    return 'CANA-$numero';
  }

  /// Crea un nuevo grupo de trabajo (el creador pasa a ser 'lider')
  static Future<Map<String, dynamic>> crearGrupo(String nombreGrupo) async {
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para crear un grupo.';

    final codigo = _generarCodigoGrupo();

    final grupo = await client
        .from('grupos')
        .insert({
          'nombre': nombreGrupo.trim(),
          'codigo_invitacion': codigo,
          'lider_id': user.id,
        })
        .select()
        .single();

    final grupoId = grupo['id'];

    // Actualizar perfil del usuario a Líder y asignar grupo_id
    await client.from('perfiles').update({
      'grupo_id': grupoId,
      'rol': 'lider',
    }).eq('id', user.id);

    await loadProfile();
    return grupo;
  }

  /// Unirse a un grupo mediante código de invitación (rol 'empleado')
  static Future<Map<String, dynamic>> unirseAGrupo(String codigo) async {
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para unirte a un grupo.';

    final cleanCodigo = codigo.trim().toUpperCase();

    final grupo = await client
        .from('grupos')
        .select()
        .eq('codigo_invitacion', cleanCodigo)
        .maybeSingle();

    if (grupo == null) {
      throw 'No se encontró ninguna cuadrilla con el código $cleanCodigo.';
    }

    final grupoId = grupo['id'];

    // Asignar al perfil
    await client.from('perfiles').update({
      'grupo_id': grupoId,
      'rol': 'empleado',
    }).eq('id', user.id);

    await loadProfile();
    return grupo;
  }

  /// Salir del grupo actual
  static Future<void> salirDeGrupo() async {
    final user = currentUser;
    if (user == null) return;

    await client.from('perfiles').update({
      'grupo_id': null,
      'rol': 'empleado',
    }).eq('id', user.id);

    await loadProfile();
  }

  /// Obtiene los datos del grupo del usuario actual
  static Future<Map<String, dynamic>?> getMiGrupo() async {
    final grupoId = currentGrupoId;
    if (grupoId == null) return null;

    try {
      final grupo =
          await client.from('grupos').select().eq('id', grupoId).maybeSingle();

      if (grupo != null) {
        // Obtener nombre del líder
        final lider = await client
            .from('perfiles')
            .select('nombre_completo')
            .eq('id', grupo['lider_id'])
            .maybeSingle();
        grupo['lider_nombre'] = lider?['nombre_completo'] ?? 'Líder';
      }

      return grupo;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene la lista de miembros de un grupo
  static Future<List<Map<String, dynamic>>> getMiembrosGrupo(
      String grupoId) async {
    try {
      final data = await client
          .from('perfiles')
          .select('id, dni, nombre_completo, rol, created_at')
          .eq('grupo_id', grupoId)
          .order('rol', ascending: false)
          .order('nombre_completo', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  /// Expulsa a un miembro del grupo (Solo para el Líder)
  static Future<bool> removerMiembro(String usuarioId) async {
    try {
      await client.from('perfiles').update({
        'grupo_id': null,
        'rol': 'empleado',
      }).eq('id', usuarioId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ========================================================================
  // HISTORIAL, STORAGE Y TRATAMIENTO
  // ========================================================================

  /// Sube la imagen del escaneo al bucket 'escaneos'
  static Future<String?> uploadScanImage(File file) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_leaf.$fileExt';
      final filePath = '${user.id}/$fileName';

      await client.storage.from('escaneos').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fileExt == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );

      return client.storage.from('escaneos').getPublicUrl(filePath);
    } catch (_) {
      return null;
    }
  }

  /// Guarda el diagnóstico con soporte para grupo, GPS y estado de tratamiento
  static Future<bool> saveDiagnosisRecord({
    required String? imageUrl,
    required String estadoGeneral,
    required String? diagnosticoPrincipal,
    required double? confianzaMaxima,
    required double imagenAncho,
    required double imagenAlto,
    required List<dynamic> detecciones,
    String? grupoId,
    double? latitud,
    double? longitud,
    String origenFoto = 'camara',
  }) async {
    try {
      final user = currentUser;
      if (user == null) return false;

      await client.from('historial_escaneos').insert({
        'user_id': user.id,
        'grupo_id': grupoId,
        'image_url': imageUrl ?? '',
        'estado_general': estadoGeneral,
        'diagnostico_principal': diagnosticoPrincipal,
        'confianza_maxima': confianzaMaxima,
        'imagen_ancho': imagenAncho,
        'imagen_alto': imagenAlto,
        'detecciones': detecciones,
        'latitud': latitud,
        'longitud': longitud,
        'origen_foto': origenFoto,
        'estado_tratamiento': 'pendiente',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene los escaneos del grupo (historial compartido)
  static Future<List<Map<String, dynamic>>> getGroupHistory(
      String grupoId) async {
    try {
      final response = await client
          .from('historial_escaneos')
          .select()
          .eq('grupo_id', grupoId)
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);

      // Cargar nombres de miembros del grupo para enriquecer
      final miembros = await getMiembrosGrupo(grupoId);
      final nombresMap = {for (var m in miembros) m['id']: m['nombre_completo']};

      for (var item in list) {
        final uid = item['user_id'];
        item['usuario_nombre'] = nombresMap[uid] ?? 'Compañero';
      }

      return list;
    } catch (_) {
      return [];
    }
  }

  /// Obtiene los escaneos personales del usuario autenticado
  static Future<List<Map<String, dynamic>>> getPersonalHistory() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final response = await client
          .from('historial_escaneos')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Actualiza el estado de tratamiento de una hoja enferma ('tratado' o 'descartado')
  static Future<bool> actualizarEstadoTratamiento({
    required String scanId,
    required String nuevoEstado, // 'tratado' | 'descartado' | 'pendiente'
    String? notas,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    try {
      await client.from('historial_escaneos').update({
        'estado_tratamiento': nuevoEstado,
        'tratado_por': user.id,
        'fecha_tratamiento': DateTime.now().toIso8601String(),
        'notas_tratamiento': notas,
      }).eq('id', scanId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Elimina un registro del historial
  static Future<bool> deleteHistoryRecord(String recordId) async {
    try {
      await client.from('historial_escaneos').delete().eq('id', recordId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Traduce los mensajes comunes de Supabase a mensajes amigables en español
  static String _traducirErrorAuth(String mensajeOriginal) {
    final lower = mensajeOriginal.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'DNI o PIN incorrecto.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already registered') ||
        lower.contains('user_already_exists')) {
      return 'Este DNI ya está registrado en el sistema.';
    }
    if (lower.contains('password should be at least')) {
      return 'El PIN debe tener al menos 4 números.';
    }
    if (lower.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos momentos antes de reintentar.';
    }
    return mensajeOriginal;
  }
}
