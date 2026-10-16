import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloDetection {
  final String clase;
  final double confianza;
  final List<double> bbox; // [x1, y1, x2, y2]

  const YoloDetection({
    required this.clase,
    required this.confianza,
    required this.bbox,
  });

  Map<String, dynamic> toMap() {
    return {
      'clase': clase,
      'confianza': confianza,
      'bbox': bbox,
    };
  }
}

class YoloService {
  static Interpreter? _interpreterHoja;
  static Interpreter? _interpreterAfeccion;

  static List<String> _labelsHoja = [];
  static List<String> _labelsAfeccion = [];

  static bool _inicializado = false;

  static const int inputSize = 640;
  static const double confThresholdHoja = 0.20;
  static const double confThresholdAfeccion = 0.20;
  static const double iouThreshold = 0.45;

  /// Inicializa los dos intérpretes de TFLite y carga las etiquetas
  static Future<bool> initialize() async {
    if (_inicializado) return true;

    try {
      // 1. Cargar etiquetas
      final rawHoja =
          await rootBundle.loadString('assets/models/hoja_labels.txt');
      _labelsHoja = rawHoja
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final rawAfec =
          await rootBundle.loadString('assets/models/afeccion_labels.txt');
      _labelsAfeccion = rawAfec
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // 2. Cargar modelos TFLite
      final options = InterpreterOptions()..threads = 4;

      _interpreterHoja = await Interpreter.fromAsset(
        'assets/models/MODELO_HOJA.tflite',
        options: options,
      );

      _interpreterAfeccion = await Interpreter.fromAsset(
        'assets/models/MODELO_AFECCION.tflite',
        options: options,
      );

      _inicializado = true;
      return true;
    } catch (e) {
      // Los archivos .tflite aún no han sido colocados en assets/models/
      return false;
    }
  }

  /// Indica si los modelos locales están listos para inferencia offline
  static bool get isReady =>
      _inicializado &&
      _interpreterHoja != null &&
      _interpreterAfeccion != null;

  /// Diagnóstico completo en dos etapas usando los modelos integrados en el APK
  static Future<Map<String, dynamic>> predict(File imageFile) async {
    final ready = await initialize();
    if (!ready) {
      throw Exception(
        'Los modelos TFLite aún no están disponibles en assets/models/. '
        'Asegúrate de colocar MODELO_HOJA.tflite y MODELO_AFECCION.tflite.',
      );
    }

    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('No se pudo decodificar la imagen seleccionada.');
    }

    final origW = originalImage.width.toDouble();
    final origH = originalImage.height.toDouble();

    // Preprocesamiento a 640x640 normalizado [0.0, 1.0]
    final resized = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final inputBuffer = _imageToByteBuffer(resized);

    // ========================================================================
    // ETAPA 1: Comprobar si es hoja de caña de azúcar
    // ========================================================================
    final shapeHoja = _interpreterHoja!.getOutputTensor(0).shape;
    final outputHoja = _createOutputBuffer(shapeHoja);

    _interpreterHoja!.run(inputBuffer, outputHoja);

    final deteccionesHoja = _postprocessYolo(
      outputHoja,
      shapeHoja,
      _labelsHoja,
      confThresholdHoja,
      origW,
      origH,
    );

    // Si el primer modelo no detecta 'hoja_cana', devolvemos lista vacía
    if (deteccionesHoja.isEmpty) {
      return {
        'imagen_ancho': origW,
        'imagen_alto': origH,
        'detecciones': [],
      };
    }

    // ========================================================================
    // ETAPA 2: Diagnosticar afecciones en la hoja
    // ========================================================================
    final shapeAfec = _interpreterAfeccion!.getOutputTensor(0).shape;
    final outputAfec = _createOutputBuffer(shapeAfec);

    _interpreterAfeccion!.run(inputBuffer, outputAfec);

    final deteccionesAfeccion = _postprocessYolo(
      outputAfec,
      shapeAfec,
      _labelsAfeccion,
      confThresholdAfeccion,
      origW,
      origH,
    );

    return {
      'imagen_ancho': origW,
      'imagen_alto': origH,
      'detecciones': deteccionesAfeccion.map((d) => d.toMap()).toList(),
    };
  }

  /// Convierte la imagen RGB en un buffer float32 normalizado de [1, 640, 640, 3]
  static Float32List _imageToByteBuffer(img.Image image) {
    final buffer = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[pixelIndex++] = pixel.r / 255.0;
        buffer[pixelIndex++] = pixel.g / 255.0;
        buffer[pixelIndex++] = pixel.b / 255.0;
      }
    }

    return buffer.reshape([1, inputSize, inputSize, 3]) as Float32List;
  }

  /// Crea la estructura de matriz de salida según el shape del tensor de salida
  static Object _createOutputBuffer(List<int> shape) {
    if (shape.length == 3) {
      return List.generate(
        shape[0],
        (_) => List.generate(
          shape[1],
          (_) => List.filled(shape[2], 0.0),
        ),
      );
    }
    return List.filled(shape.reduce((a, b) => a * b), 0.0);
  }

  /// Decodifica la matriz de salida YOLOv8 y aplica Non-Maximum Suppression (NMS)
  static List<YoloDetection> _postprocessYolo(
    Object rawOutput,
    List<int> shape,
    List<String> labels,
    double confThreshold,
    double origW,
    double origH,
  ) {
    final List<YoloDetection> candidates = [];

    // YOLOv8 shape estándar: [1, 4 + num_classes, 8400]
    final isChannelsFirst = shape[1] < shape[2];
    final numAttrs = isChannelsFirst ? shape[1] : shape[2];
    final numAnchors = isChannelsFirst ? shape[2] : shape[1];
    final numClasses = labels.length;

    final outputList = (rawOutput as List)[0] as List;

    for (int anchor = 0; anchor < numAnchors; anchor++) {
      // 1. Obtener coordenadas del bounding box [cx, cy, w, h] en escala 0-640
      double cx, cy, w, h;

      if (isChannelsFirst) {
        cx = (outputList[0][anchor] as num).toDouble();
        cy = (outputList[1][anchor] as num).toDouble();
        w = (outputList[2][anchor] as num).toDouble();
        h = (outputList[3][anchor] as num).toDouble();
      } else {
        cx = (outputList[anchor][0] as num).toDouble();
        cy = (outputList[anchor][1] as num).toDouble();
        w = (outputList[anchor][2] as num).toDouble();
        h = (outputList[anchor][3] as num).toDouble();
      }

      // 2. Encontrar la clase con mayor confianza
      int bestClassIdx = -1;
      double maxScore = -1.0;

      for (int c = 0; c < numClasses && (4 + c) < numAttrs; c++) {
        final double score = isChannelsFirst
            ? (outputList[4 + c][anchor] as num).toDouble()
            : (outputList[anchor][4 + c] as num).toDouble();

        if (score > maxScore) {
          maxScore = score;
          bestClassIdx = c;
        }
      }

      if (maxScore >= confThreshold && bestClassIdx >= 0) {
        // Convertir de [cx, cy, w, h] relativo a 640 -> [x1, y1, x2, y2] en coordenadas originales
        final double scaleX = origW / inputSize;
        final double scaleY = origH / inputSize;

        final double x1 = max(0.0, (cx - w / 2) * scaleX);
        final double y1 = max(0.0, (cy - h / 2) * scaleY);
        final double x2 = min(origW, (cx + w / 2) * scaleX);
        final double y2 = min(origH, (cy + h / 2) * scaleY);

        candidates.add(
          YoloDetection(
            clase: labels[bestClassIdx],
            confianza: maxScore,
            bbox: [x1, y1, x2, y2],
          ),
        );
      }
    }

    // 3. Aplicar Non-Maximum Suppression (NMS)
    return _applyNms(candidates, iouThreshold);
  }

  /// Algoritmo de supresión de no máximos para evitar cajas superpuestas
  static List<YoloDetection> _applyNms(
    List<YoloDetection> boxes,
    double iouThreshold,
  ) {
    boxes.sort((a, b) => b.confianza.compareTo(a.confianza));
    final List<YoloDetection> selected = [];

    for (final box in boxes) {
      bool keep = true;
      for (final prev in selected) {
        if (_calculateIou(box.bbox, prev.bbox) > iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) {
        selected.add(box);
      }
    }

    return selected;
  }

  static double _calculateIou(List<double> a, List<double> b) {
    final double x1 = max(a[0], b[0]);
    final double y1 = max(a[1], b[1]);
    final double x2 = min(a[2], b[2]);
    final double y2 = min(a[3], b[3]);

    final double intersectionArea = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    final double areaA = (a[2] - a[0]) * (a[3] - a[1]);
    final double areaB = (b[2] - b[0]) * (b[3] - b[1]);

    final double unionArea = areaA + areaB - intersectionArea;
    if (unionArea <= 0.0) return 0.0;

    return intersectionArea / unionArea;
  }
}
