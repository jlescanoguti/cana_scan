import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dni_service.dart';
import '../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _nombreController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _respuestaAuxilioController = TextEditingController();

  final List<String> _preguntasDisponibles = [
    '¿Cuál es el nombre de tu mamá?',
    '¿Cuál es el nombre de tu pueblo o caserío natal?',
    '¿Cuál es el nombre de tu primera mascota?',
    '¿Cuál es el nombre de tu hacienda o finca favorita?',
  ];

  late String _preguntaSeleccionada;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _preguntaSeleccionada = _preguntasDisponibles.first;
  }

  @override
  void dispose() {
    _dniController.dispose();
    _nombreController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _respuestaAuxilioController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dni = _dniController.text.trim();
      final nombre = _nombreController.text.trim();
      final pin = _pinController.text.trim();
      final respuesta = _respuestaAuxilioController.text.trim();

      await SupabaseService.signUp(
        dni: dni,
        nombreCompleto: nombre,
        pin: pin,
        preguntaAuxilio: _preguntaSeleccionada,
        respuestaAuxilio: respuesta,
      );

      // Cerrar sesión automática para obligar a autenticarse explícitamente
      await SupabaseService.signOut();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Diálogo de éxito
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2D7A2D), size: 28),
              SizedBox(width: 10),
              Text(
                'Registro exitoso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Bienvenido, $nombre!',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B3A1B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu cuenta ha sido creada con el DNI: $dni.\n\n'
                'Ahora ingresa tu DNI y tu PIN en la pantalla de inicio de sesión.',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4A5D4A),
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D7A2D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, dni);
              },
              child: const Text('Ir a Iniciar sesión'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1B3A1B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7A2D),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Crear Cuenta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B3A1B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Regístrate para guardar diagnósticos y unirte a tu cuadrilla',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A5D4A),
                  ),
                ),

                const SizedBox(height: 22),

                // Formulario
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFD7E5D7),
                      width: 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Color(0xFFD32F2F),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // DNI
                        const Text(
                          'Número de DNI (8 dígitos)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _dniController,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _inputDecoration(
                            hint: '8 dígitos numéricos',
                            icon: Icons.badge_outlined,
                          ),
                          validator: DniService.validarFormatoDni,
                        ),

                        const SizedBox(height: 14),

                        // Nombre Completo
                        const Text(
                          'Nombre y Apellidos completos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombreController,
                          textCapitalization: TextCapitalization.words,
                          decoration: _inputDecoration(
                            hint: 'ej: Carlos Gómez Pérez',
                            icon: Icons.person_outline_rounded,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 3) {
                              return 'Por favor ingresa tu nombre completo';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // PIN
                        const Text(
                          'PIN numérico (4 a 6 números)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: _obscurePin,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _inputDecoration(
                            hint: 'Elige un PIN que recuerdes',
                            icon: Icons.pin_outlined,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF6B806B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePin = !_obscurePin;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 4) {
                              return 'El PIN debe tener al menos 4 números';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // Confirmar PIN
                        const Text(
                          'Confirmar tu PIN',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: _obscureConfirmPin,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _inputDecoration(
                            hint: 'Repite tu PIN',
                            icon: Icons.lock_clock_outlined,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirmPin
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF6B806B),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPin = !_obscureConfirmPin;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirma tu PIN';
                            }
                            if (value != _pinController.text) {
                              return 'Los PIN no coinciden';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // Banner de Auxilio
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC8E6C9)),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFF2D7A2D), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pregunta de auxilio: solo te la pediremos si llegas a olvidar tu PIN para que puedas recuperarlo tú mismo.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF1B3A1B),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Selector Pregunta
                        const Text(
                          'Elige tu pregunta de auxilio',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FBF9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD7E5D7)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _preguntaSeleccionada,
                              icon: const Icon(Icons.arrow_drop_down_rounded,
                                  color: Color(0xFF2D7A2D)),
                              items: _preguntasDisponibles
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF1B3A1B))),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _preguntaSeleccionada = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Respuesta Auxilio
                        const Text(
                          'Tu respuesta secreta',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _respuestaAuxilioController,
                          decoration: _inputDecoration(
                            hint: 'Escribe tu respuesta',
                            icon: Icons.key_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().length < 2) {
                              return 'Ingresa una respuesta que recuerdes';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Botón Registrarse
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D7A2D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _handleRegister,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.person_add_rounded, size: 20),
                            label: const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Volver a login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B806B),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Inicia sesión aquí',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D7A2D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      counterText: '',
      hintStyle: const TextStyle(
        color: Color(0xFFA0B0A0),
        fontSize: 13.5,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF6B806B), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF9FBF9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7E5D7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7E5D7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D7A2D), width: 1.5),
      ),
    );
  }
}
