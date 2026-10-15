import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/dni_service.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dniController = TextEditingController();
  final _pinController = TextEditingController();

  bool _obscurePin = true;
  bool _isLoading = false;
  bool _recordarCredenciales = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  Future<void> _cargarCredencialesGuardadas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recordar = prefs.getBool('remember_credentials') ?? false;
      if (recordar) {
        final dni = prefs.getString('saved_dni') ?? '';
        final pin = prefs.getString('saved_pin') ?? '';
        if (mounted) {
          setState(() {
            _recordarCredenciales = true;
            _dniController.text = dni;
            _pinController.text = pin;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _dniController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dni = _dniController.text.trim();
      final pin = _pinController.text.trim();

      await SupabaseService.signIn(dni: dni, pin: pin);

      final prefs = await SharedPreferences.getInstance();
      if (_recordarCredenciales) {
        await prefs.setBool('remember_credentials', true);
        await prefs.setString('saved_dni', dni);
        await prefs.setString('saved_pin', pin);
      } else {
        await prefs.remove('remember_credentials');
        await prefs.remove('saved_dni');
        await prefs.remove('saved_pin');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarRecuperarPin() {
    final dniRecupController = TextEditingController(text: _dniController.text);
    final respuestaController = TextEditingController();
    final nuevoPinController = TextEditingController();

    String? preguntaCargada;
    bool buscandoDni = false;
    bool guardando = false;
    String? errorModal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.help_outline_rounded,
                        color: Color(0xFF2D7A2D), size: 26),
                    const SizedBox(width: 10),
                    const Text(
                      'Recuperar PIN con Pregunta de Auxilio',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ingresa tu DNI para responder la pregunta secreta que registraste.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4A5D4A)),
                ),
                const SizedBox(height: 16),
                if (errorModal != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorModal!,
                      style: const TextStyle(
                          color: Color(0xFFC62828), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Número de DNI',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1B3A1B)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: dniRecupController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '8 dígitos',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                if (preguntaCargada == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D7A2D),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: buscandoDni
                          ? null
                          : () async {
                              final dni = dniRecupController.text.trim();
                              if (DniService.validarFormatoDni(dni) != null) {
                                setModalState(() {
                                  errorModal = 'Ingresa un DNI válido de 8 números';
                                });
                                return;
                              }

                              setModalState(() {
                                buscandoDni = true;
                                errorModal = null;
                              });

                              final pregunta =
                                  await SupabaseService.getPreguntaAuxilio(dni);

                              setModalState(() {
                                buscandoDni = false;
                                if (pregunta == null) {
                                  errorModal =
                                      'No se encontró una cuenta con ese DNI';
                                } else {
                                  preguntaCargada = pregunta;
                                }
                              });
                            },
                      icon: buscandoDni
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Buscar mi pregunta'),
                    ),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tu pregunta de auxilio es:',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF2D7A2D))),
                        const SizedBox(height: 4),
                        Text(
                          preguntaCargada!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1B3A1B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tu respuesta secreta',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B3A1B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: respuestaController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu respuesta',
                      prefixIcon: Icon(Icons.key_outlined, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nuevo PIN (4 a 6 números)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1B3A1B))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nuevoPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Nuevo PIN',
                      prefixIcon: Icon(Icons.lock_reset_rounded, size: 20),
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D7A2D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: guardando
                          ? null
                          : () async {
                              final resp = respuestaController.text.trim();
                              final nuevoPin = nuevoPinController.text.trim();
                              if (resp.isEmpty) {
                                setModalState(() {
                                  errorModal = 'Ingresa tu respuesta de auxilio';
                                });
                                return;
                              }
                              if (nuevoPin.length < 4) {
                                setModalState(() {
                                  errorModal = 'El nuevo PIN debe tener al menos 4 números';
                                });
                                return;
                              }

                              setModalState(() {
                                guardando = true;
                                errorModal = null;
                              });

                              try {
                                await SupabaseService.restablecerPinConAuxilio(
                                  dni: dniRecupController.text.trim(),
                                  respuestaAuxilio: resp,
                                  nuevoPin: nuevoPin,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'PIN actualizado con éxito. Ya puedes iniciar sesión.'),
                                      backgroundColor: Color(0xFF2D7A2D),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  guardando = false;
                                  errorModal = e.toString();
                                });
                              }
                            },
                      child: guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Actualizar mi PIN',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo y Marca
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D7A2D),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D7A2D).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 38)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CañaScan',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B3A1B),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Diagnóstico foliar inteligente',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A5D4A),
                  ),
                ),

                const SizedBox(height: 30),

                // Tarjeta de Formulario
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
                        const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B3A1B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Accede con tu DNI y tu PIN de 4 números',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B806B),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error
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
                                const Icon(Icons.error_outline_rounded,
                                    color: Color(0xFFD32F2F), size: 20),
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
                          'Número de DNI',
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
                          decoration: InputDecoration(
                            hintText: '8 dígitos',
                            counterText: '',
                            hintStyle: const TextStyle(
                                color: Color(0xFFA0B0A0), fontSize: 14),
                            prefixIcon: const Icon(Icons.badge_outlined,
                                color: Color(0xFF6B806B), size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: DniService.validarFormatoDni,
                        ),

                        const SizedBox(height: 14),

                        // PIN
                        const Text(
                          'Tu PIN de acceso',
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
                          decoration: InputDecoration(
                            hintText: '4 a 6 números',
                            counterText: '',
                            hintStyle: const TextStyle(
                                color: Color(0xFFA0B0A0), fontSize: 14),
                            prefixIcon: const Icon(Icons.pin_outlined,
                                color: Color(0xFF6B806B), size: 20),
                            suffixIcon: IconButton(
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
                            filled: true,
                            fillColor: const Color(0xFFF9FBF9),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa tu PIN';
                            }
                            if (value.trim().length < 4) {
                              return 'El PIN tiene al menos 4 números';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        // Recordar + Olvidó su clave
                        Row(
                          children: [
                            SizedBox(
                              height: 22,
                              width: 22,
                              child: Checkbox(
                                value: _recordarCredenciales,
                                activeColor: const Color(0xFF2D7A2D),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _recordarCredenciales = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _recordarCredenciales = !_recordarCredenciales;
                                });
                              },
                              child: const Text(
                                'Recordar datos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4A5D4A),
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _mostrarRecuperarPin,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '¿Olvidaste tu PIN?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D7A2D),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Botón Iniciar Sesión
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D7A2D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded, size: 20),
                            label: const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Botón Modo Invitado
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2D7A2D),
                              side: const BorderSide(color: Color(0xFF2D7A2D)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HomeScreen()),
                              );
                            },
                            icon: const Icon(Icons.flash_on_rounded, size: 18),
                            label: const Text(
                              'Continuar sin cuenta (Invitado)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Enlace a Registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Aún no te has registrado?',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B806B)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final dniRegistrado = await Navigator.push<String>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                        if (dniRegistrado != null && mounted) {
                          _dniController.text = dniRegistrado;
                          _pinController.clear();
                        }
                      },
                      child: const Text(
                        'Regístrate aquí',
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
}
