import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  test('Test floatList reshape in tflite_flutter', () {
    final list = Float32List(1 * 3 * 2 * 2);
    for (int i = 0; i < list.length; i++) {
      list[i] = i.toDouble();
    }
    final reshaped = list.reshape([1, 3, 2, 2]);
    expect(reshaped, isA<List>());
    expect(reshaped.length, equals(1));
    expect(reshaped[0].length, equals(3));
    expect(reshaped[0][0].length, equals(2));
    expect(reshaped[0][0][0].length, equals(2));
  });

  test('Verificar existencia de modelos TFLite y etiquetas', () {
    expect(File('assets/models/MODELO_HOJA.tflite').existsSync(), isTrue);
    expect(File('assets/models/MODELO_AFECCION.tflite').existsSync(), isTrue);
    expect(File('assets/models/hoja_labels.txt').existsSync(), isTrue);
    expect(File('assets/models/afeccion_labels.txt').existsSync(), isTrue);
  });
}
