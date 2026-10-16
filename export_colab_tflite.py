# Script para ejecutar en Google Colab (copiar y pegar en una celda)
# ------------------------------------------------------------------------------
# 1. Instalar Ultralytics
!pip install ultralytics

# 2. Subir MODELO_HOJA.pt y MODELO_AFECCION.pt al panel de archivos de Colab (a la izquierda)

# 3. Exportar a formato TFLite con cuantización Float16 (reduce a la mitad el tamaño sin perder precisión)
from ultralytics import YOLO

print("--> Exportando MODELO_HOJA...")
m_hoja = YOLO("MODELO_HOJA.pt")
m_hoja.export(format="tflite", imgsz=640, half=True)

print("--> Exportando MODELO_AFECCION...")
m_afec = YOLO("MODELO_AFECCION.pt")
m_afec.export(format="tflite", imgsz=640, half=True)

print("\nLISTO. En el panel de archivos verás dos carpetas creadas:")
print("1) 'MODELO_HOJA_saved_model/MODELO_HOJA_float16.tflite' -> Descárgalo y guárdalo en tu app como: assets/models/MODELO_HOJA.tflite")
print("2) 'MODELO_AFECCION_saved_model/MODELO_AFECCION_float16.tflite' -> Descárgalo y guárdalo en tu app como: assets/models/MODELO_AFECCION.tflite")
