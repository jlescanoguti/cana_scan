# Script para ejecutar en Google Colab (copiar y pegar en una celda)
# ------------------------------------------------------------------------------
# 1. Instalar Ultralytics
!pip install ultralytics

# 2. Subir MODELO_HOJA.pt y MODELO_AFECCION.pt al panel de archivos de Colab (a la izquierda)

# 3. Exportar a formato TFLite con cuantización Float16 (reduce a la mitad el tamaño sin perder precisión)
from ultralytics import YOLO

print("--> Exportando MODELO_HOJA...")
m_hoja = YOLO("MODELO_HOJA.pt")
m_hoja.export(format="litert", imgsz=640)

print("--> Exportando MODELO_AFECCION...")
m_afec = YOLO("MODELO_AFECCION.pt")
m_afec.export(format="litert", imgsz=640)

print("\nLISTO. En el panel de archivos de Colab verás los archivos .tflite generados:")
print("1) Descarga el modelo de la hoja y guárdalo como: assets/models/MODELO_HOJA.tflite")
print("2) Descarga el modelo de afecciones y guárdalo como: assets/models/MODELO_AFECCION.tflite")
