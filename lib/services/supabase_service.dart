import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acceso a Supabase.
///
/// Las operaciones sensibles (registro de perfil, recuperación de PIN,
/// cuadrillas y tratamiento) se hacen mediante funciones RPC definidas en
/// `supabase/migrations/20261112_seguridad_cuadrillas.sql`, que validan los
/// permisos en el servidor. Los errores se lanzan como `String` con un mensaje
/// listo para mostrar al usuario.
class SupabaseService {
  static const String supabaseUrl = 'https://rdrcnsiwxuxzuuvdgysu.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkcmNuc2l3eHV4enV1dmRneXN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk5NDY3NjksImV4cCI6MjEwNTUyMjc2OX0.KvEmVYn7aJJvpJ93oK8aevkwii5hBTOklVdElylXZHU';

  static const String _bucketEscaneos = 'escaneos';

  /// Columnas de `perfiles` que la app puede leer (nunca `respuesta_auxilio`).
  static const String _columnasPerfil = 'id, dni, nombre_completo, grupo_id, rol';

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
    final nombre = _currentProfile?['nombre_completo'];
    return nombre != null ? nombre.toString() : 'Agricultor';
  }

  /// Rol del usuario en su cuadrilla activa ('lider' o 'empleado')
  static String get currentRol {
    final rol = _currentProfile?['rol'];
    return rol != null ? rol.toString() : 'empleado';
  }

  /// ID del grupo actual del usuario (o null si es independiente)
  static String? get currentGrupoId {
    final grupoId = _currentProfile?['grupo_id'];
    return grupoId?.toString();
  }

  /// Mapea un DNI a un email interno de Supabase
  static String dniToEmail(String dni) => '${dni.trim()}@canascan.app';

  /// Mapea un PIN numérico a la contraseña interna
  static String pinToPassword(String pin) => 'pin_${pin.trim()}';

  // ========================================================================
  // AUTENTICACIÓN Y PERFIL
  // ========================================================================

  /// Registra una nueva cuenta por DNI + PIN + datos de auxilio.
  ///
  /// Si un registro anterior creó la cuenta pero no el perfil (por ejemplo,
  /// por un corte de conexión), se completa el perfil usando el mismo PIN.
  static Future<void> signUp({
    required String dni,
    required String nombreCompleto,
    required String pin,
    required String preguntaAuxilio,
    required String respuestaAuxilio,
  }) async {
    final cleanDni = dni.trim();
    final email = dniToEmail(cleanDni);
    final password = pinToPassword(pin);

    try {
      try {
        await client.auth.signUp(
          email: email,
          password: password,
          data: {'dni': cleanDni, 'nombre': nombreCompleto.trim()},
        );
      } on AuthException catch (e) {
        if (!_esUsuarioYaRegistrado(e.message)) rethrow;
        // Cuenta existente: si el PIN coincide y no tiene perfil, lo completamos
        try {
          await client.auth
              .signInWithPassword(email: email, password: password);
        } on AuthException {
          throw 'Este DNI ya cuenta con una cuenta registrada.';
        }
        final perfil = await client
            .from('perfiles')
            .select('id')
            .eq('id', client.auth.currentUser!.id)
            .maybeSingle();
        if (perfil != null) {
          await client.auth.signOut();
          throw 'Este DNI ya cuenta con una cuenta registrada.';
        }
      }

      if (client.auth.currentUser == null) {
        throw 'No se pudo iniciar la sesión del registro. Revisa que la '
            'confirmación por correo esté desactivada en Supabase.';
      }

      await client.rpc('registrar_perfil', params: {
        'p_nombre': nombreCompleto.trim(),
        'p_pregunta': preguntaAuxilio.trim(),
        'p_respuesta': respuestaAuxilio.trim(),
      });
    } on AuthException catch (e) {
      throw _traducirErrorAuth(e.message);
    } on PostgrestException catch (e) {
      if (e.message.contains('duplicate key') ||
          e.message.contains('perfiles_dni_key')) {
        throw 'Este DNI ya cuenta con una cuenta registrada.';
      }
      throw e.message;
    } on String {
      rethrow;
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Inicia sesión con DNI y PIN
  static Future<void> signIn({
    required String dni,
    required String pin,
  }) async {
    try {
      await client.auth.signInWithPassword(
        email: dniToEmail(dni),
        password: pinToPassword(pin),
      );
    } on AuthException catch (e) {
      throw _traducirErrorAuth(e.message);
    } catch (e) {
      throw _mensajeError(e);
    }

    // Cargar perfil en memoria (si falla, la sesión sigue siendo válida)
    try {
      await loadProfile();
    } catch (_) {}
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
          .select(_columnasPerfil)
          .eq('id', user.id)
          .maybeSingle();
      _currentProfile = data;
      return data;
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Cierra la sesión activa
  static Future<void> signOut() async {
    _currentProfile = null;
    await client.auth.signOut();
  }

  /// Obtiene la pregunta de auxilio de un DNI (funciona sin sesión).
  /// Devuelve null si el DNI no está registrado.
  static Future<String?> getPreguntaAuxilio(String dni) async {
    try {
      final pregunta = await client.rpc(
        'obtener_pregunta_auxilio',
        params: {'p_dni': dni.trim()},
      );
      return pregunta?.toString();
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Verifica la respuesta de auxilio en el servidor y restablece el PIN
  static Future<void> restablecerPinConAuxilio({
    required String dni,
    required String respuestaAuxilio,
    required String nuevoPin,
  }) async {
    final Object? estado;
    try {
      estado = await client.rpc('restablecer_pin', params: {
        'p_dni': dni.trim(),
        'p_respuesta': respuestaAuxilio.trim(),
        'p_nuevo_pin': nuevoPin.trim(),
      });
    } catch (e) {
      throw _mensajeError(e);
    }

    switch (estado) {
      case 'ok':
        return;
      case 'respuesta_incorrecta':
        throw 'La respuesta de auxilio no coincide.';
      case 'bloqueado':
        throw 'Demasiados intentos fallidos. Espera 15 minutos e inténtalo de nuevo.';
      case 'pin_invalido':
        throw 'El nuevo PIN debe tener entre 4 y 6 números.';
      default:
        throw 'No se pudo restablecer el PIN. Inténtalo más tarde.';
    }
  }

  // ========================================================================
  // GESTIÓN DE CUADRILLAS / GRUPOS DE TRABAJO
  // ========================================================================

  /// Crea un nuevo grupo de trabajo (el creador pasa a ser 'lider')
  static Future<Map<String, dynamic>> crearGrupo(String nombreGrupo) async {
    _exigirSesion('crear una cuadrilla');
    final grupo = await _rpc('crear_grupo', {'p_nombre': nombreGrupo.trim()});
    await loadProfile();
    return Map<String, dynamic>.from(grupo as Map);
  }

  /// Unirse a un grupo mediante código de invitación
  static Future<Map<String, dynamic>> unirseAGrupo(String codigo) async {
    _exigirSesion('unirte a una cuadrilla');
    final grupo = await _rpc('unirse_a_grupo', {'p_codigo': codigo.trim()});
    await loadProfile();
    return Map<String, dynamic>.from(grupo as Map);
  }

  /// Salir del grupo actual (como empleado)
  static Future<void> salirDeGrupo() async {
    _exigirSesion('salir de la cuadrilla');
    await _rpc('salir_de_grupo');
    await loadProfile();
  }

  /// Transfiere el liderazgo a otro integrante y retira al líder actual
  static Future<void> transferirLiderazgoYSalir(
      String grupoId, String nuevoLiderId) async {
    _exigirSesion('transferir el liderazgo');
    await _rpc('transferir_liderazgo', {
      'p_grupo_id': grupoId,
      'p_nuevo_lider': nuevoLiderId,
    });
    await loadProfile();
  }

  /// Disuelve una cuadrilla: desvincula miembros y elimina el grupo
  static Future<void> disolverCuadrilla(String grupoId) async {
    _exigirSesion('disolver la cuadrilla');
    await _rpc('disolver_cuadrilla', {'p_grupo_id': grupoId});
    await loadProfile();
  }

  /// Expulsa a un miembro del grupo (solo el líder)
  static Future<void> removerMiembro(String usuarioId) async {
    _exigirSesion('remover integrantes');
    await _rpc('remover_miembro', {'p_usuario_id': usuarioId});
  }

  /// Cambia el grupo activo del líder
  static Future<void> seleccionarGrupoActivo(String grupoId) async {
    _exigirSesion('cambiar de cuadrilla');
    await _rpc('cambiar_grupo_activo', {'p_grupo_id': grupoId});
    await loadProfile();
  }

  /// Obtiene los datos del grupo activo del usuario (o null si no tiene)
  static Future<Map<String, dynamic>?> getMiGrupo() async {
    final grupoId = currentGrupoId;
    if (grupoId == null) return null;

    try {
      final grupo =
          await client.from('grupos').select().eq('id', grupoId).maybeSingle();

      if (grupo != null) {
        final lider = await client
            .from('perfiles')
            .select('nombre_completo')
            .eq('id', grupo['lider_id'])
            .maybeSingle();
        grupo['lider_nombre'] = lider?['nombre_completo'] ?? 'Líder';
      }
      return grupo;
    } catch (e) {
      throw _mensajeError(e);
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
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Obtiene todos los grupos que lidera el usuario actual
  static Future<List<Map<String, dynamic>>> getMisGruposComoLider() async {
    final user = currentUser;
    if (user == null) return [];

    try {
      final res = await client
          .from('grupos')
          .select()
          .eq('lider_id', user.id)
          .order('created_at', ascending: false);

      final grupos = List<Map<String, dynamic>>.from(res);
      for (final g in grupos) {
        g['lider_nombre'] = currentNombre;
      }
      return grupos;
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  // ========================================================================
  // HISTORIAL, STORAGE Y TRATAMIENTO
  // ========================================================================

  /// Sube la imagen del escaneo a `escaneos/{user_id}/` y devuelve su URL
  /// pública. Lanza un mensaje de error si no se pudo subir.
  static Future<String> uploadScanImage(File file) async {
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para guardar la imagen.';

    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_leaf.$fileExt';
      final filePath = '${user.id}/$fileName';

      await client.storage.from(_bucketEscaneos).uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              contentType: fileExt == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );

      return client.storage.from(_bucketEscaneos).getPublicUrl(filePath);
    } catch (e) {
      throw 'No se pudo subir la imagen: ${_mensajeError(e)}';
    }
  }

  /// Guarda el diagnóstico con soporte para grupo, GPS y estado de tratamiento
  static Future<void> saveDiagnosisRecord({
    required String imageUrl,
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
    final user = currentUser;
    if (user == null) throw 'Debes iniciar sesión para guardar diagnósticos.';

    try {
      await client.from('historial_escaneos').insert({
        'user_id': user.id,
        'grupo_id': grupoId,
        'image_url': imageUrl,
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
    } catch (e) {
      throw 'No se pudo guardar el diagnóstico: ${_mensajeError(e)}';
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

      // Enriquecer con el nombre de cada autor
      final miembros = await getMiembrosGrupo(grupoId);
      final nombres = {for (final m in miembros) m['id']: m['nombre_completo']};
      for (final item in list) {
        item['usuario_nombre'] = nombres[item['user_id']] ?? 'Compañero';
      }
      return list;
    } catch (e) {
      throw _mensajeError(e);
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
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Indica si el usuario actual puede cambiar el tratamiento de un escaneo:
  /// el líder de la cuadrilla del escaneo, o el autor si es un escaneo personal.
  static bool puedeGestionarTratamiento(Map<String, dynamic> escaneo) {
    final uid = currentUser?.id;
    if (uid == null) return false;
    final grupoEscaneo = escaneo['grupo_id'];
    if (grupoEscaneo == null) return escaneo['user_id'] == uid;
    return currentRol == 'lider' && grupoEscaneo.toString() == currentGrupoId;
  }

  /// Actualiza el estado de tratamiento ('tratado' | 'descartado' | 'pendiente')
  static Future<void> actualizarEstadoTratamiento({
    required String scanId,
    required String nuevoEstado,
    String? notas,
  }) async {
    _exigirSesion('actualizar el tratamiento');
    await _rpc('actualizar_tratamiento', {
      'p_scan_id': scanId,
      'p_estado': nuevoEstado,
      'p_notas': notas,
    });
  }

  /// Elimina un registro propio del historial y su imagen en Storage
  static Future<void> deleteHistoryRecord(Map<String, dynamic> registro) async {
    final id = registro['id'].toString();
    try {
      final borrados = await client
          .from('historial_escaneos')
          .delete()
          .eq('id', id)
          .select('id');
      if (borrados.isEmpty) {
        throw 'No tienes permiso para eliminar este registro.';
      }
    } on String {
      rethrow;
    } catch (e) {
      throw _mensajeError(e);
    }

    // La imagen se borra después; si falla, el registro ya no existe y no
    // conviene mostrar error al usuario.
    final ruta = _rutaEnBucket(registro['image_url']?.toString());
    if (ruta != null) {
      try {
        await client.storage.from(_bucketEscaneos).remove([ruta]);
      } catch (_) {}
    }
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  static void _exigirSesion(String accion) {
    if (currentUser == null) throw 'Debes iniciar sesión para $accion.';
  }

  static Future<dynamic> _rpc(String funcion,
      [Map<String, dynamic>? params]) async {
    try {
      return await client.rpc(funcion, params: params);
    } catch (e) {
      throw _mensajeError(e);
    }
  }

  /// Extrae `{user_id}/{archivo}` de una URL pública del bucket
  static String? _rutaEnBucket(String? url) {
    if (url == null || url.isEmpty) return null;
    const marcador = '/$_bucketEscaneos/';
    final i = url.indexOf(marcador);
    if (i < 0) return null;
    return Uri.decodeComponent(url.substring(i + marcador.length));
  }

  static bool _esUsuarioYaRegistrado(String mensaje) {
    final lower = mensaje.toLowerCase();
    return lower.contains('already registered') ||
        lower.contains('user_already_exists') ||
        lower.contains('already been registered');
  }

  /// Convierte cualquier error en un mensaje entendible
  static String _mensajeError(Object e) {
    if (e is String) return e;
    if (e is AuthException) return _traducirErrorAuth(e.message);
    if (e is PostgrestException) {
      // Los mensajes de las funciones RPC ya vienen en español
      if (e.code == '42501' || e.message.contains('permission denied')) {
        return 'No tienes permiso para realizar esta acción.';
      }
      if (e.code == 'PGRST202') {
        return 'Falta actualizar la base de datos (función no encontrada).';
      }
      return e.message;
    }
    if (e is StorageException) return e.message;
    if (e is SocketException) {
      return 'Sin conexión a internet. Verifica tu señal e inténtalo de nuevo.';
    }
    return 'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
  }

  /// Traduce los mensajes comunes de Supabase Auth al español
  static String _traducirErrorAuth(String mensajeOriginal) {
    final lower = mensajeOriginal.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials')) {
      return 'DNI o PIN incorrecto.';
    }
    if (_esUsuarioYaRegistrado(mensajeOriginal)) {
      return 'Este DNI ya está registrado en el sistema.';
    }
    if (lower.contains('password should be at least')) {
      return 'El PIN debe tener al menos 4 números.';
    }
    if (lower.contains('rate limit')) {
      return 'Demasiados intentos. Espera unos momentos antes de reintentar.';
    }
    if (lower.contains('email not confirmed')) {
      return 'La cuenta no está confirmada. Contacta al administrador.';
    }
    return mensajeOriginal;
  }
}
