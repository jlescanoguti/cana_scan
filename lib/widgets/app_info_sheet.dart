import 'package:flutter/material.dart';

class AppInfoSheet extends StatelessWidget {
  const AppInfoSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AppInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arrastre superior
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD7E5D7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Contenido scrollable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezado
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acerca de CañaScan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B3A1B),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Diagnóstico foliar inteligente · v1.0.0',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B806B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Descripción general
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFD7E5D7),
                        width: 0.5,
                      ),
                    ),
                    child: const Text(
                      'CañaScan es una herramienta de apoyo agronómico impulsada por visión computacional. '
                      'Permite identificar de manera temprana afecciones y plagas en las hojas de los cultivos '
                      'de caña de azúcar para facilitar la toma de decisiones fitosanitarias oportunas.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF2E402E),
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Sección: Consejos de captura
                  const Text(
                    'Recomendaciones para una buena captura',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildTipItem(
                    icon: Icons.straighten_rounded,
                    titulo: 'Distancia adecuada',
                    descripcion: 'Coloca la cámara a unos 20-30 cm de la hoja para captar detalles claros de la textura.',
                  ),
                  _buildTipItem(
                    icon: Icons.wb_sunny_rounded,
                    titulo: 'Buena iluminación natural',
                    descripcion: 'Procura tomar la foto con luz de día, evitando sombras duras o reflejos directos de sol.',
                  ),
                  _buildTipItem(
                    icon: Icons.center_focus_strong_rounded,
                    titulo: 'Enfoque en la lesión',
                    descripcion: 'Asegúrate de enfocar las manchas, pústulas o decoloraciones sospechosas.',
                  ),

                  const SizedBox(height: 20),

                  // Sección: Afecciones detectadas
                  const Text(
                    'Afecciones y estados detectables',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildDiseaseItem(
                    color: const Color(0xFFFFD600),
                    nombre: 'Amarillamiento',
                    descripcion: 'Clorosis general o focalizada en láminas foliares.',
                  ),
                  _buildDiseaseItem(
                    color: Colors.red,
                    nombre: 'Podredumbre Roja',
                    descripcion: 'Lesiones rojizas características en nervaduras y tejido foliar.',
                  ),
                  _buildDiseaseItem(
                    color: Colors.blue,
                    nombre: 'Roya',
                    descripcion: 'Pústulas alargadas y manchas marrones o anaranjadas en el envés.',
                  ),
                  _buildDiseaseItem(
                    color: Colors.black,
                    nombre: 'Gusano Cogollero',
                    descripcion: 'Daño y perforaciones causados por larvas en cogollo y follaje.',
                  ),
                  _buildDiseaseItem(
                    color: Colors.green,
                    nombre: 'Saludable',
                    descripcion: 'Hoja sana sin indicios visibles de afecciones o plagas.',
                  ),

                  const SizedBox(height: 18),

                  // Aviso de descargo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFE082),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFFB78103),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Nota agronómica: El diagnóstico generado por inteligencia artificial es orientativo. '
                            'Se sugiere consultar con un profesional agrónomo antes de la aplicación de productos fitosanitarios.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B4E00),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Botón cerrar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D7A2D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Entendido',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTipItem({
    required IconData icon,
    required String titulo,
    required String descripcion,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2D7A2D)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                children: [
                  TextSpan(
                    text: '$titulo: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B3A1B),
                    ),
                  ),
                  TextSpan(
                    text: descripcion,
                    style: const TextStyle(
                      color: Color(0xFF556B55),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDiseaseItem({
    required Color color,
    required String nombre,
    required String descripcion,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4EDE4), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B3A1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B806B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
