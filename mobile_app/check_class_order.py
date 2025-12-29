#!/usr/bin/env python3
"""
Script para verificar el ORDEN REAL de las clases del modelo TFLite
"""

import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# ========================================
# CONFIGURA ESTO CON TU RUTA DE DATASET
# ========================================
DATASET_DIR = "dataset_orejas"  # Cambia por tu ruta
IMG_SIZE = (224, 224)

print("\n" + "="*60)
print("🔍 VERIFICANDO ORDEN DE CLASES DEL MODELO")
print("="*60 + "\n")

# Recrear el generador tal como lo hiciste en entrenamiento
datagen = ImageDataGenerator(rescale=1./255)

generator = datagen.flow_from_directory(
    DATASET_DIR,
    target_size=IMG_SIZE,
    batch_size=1,
    class_mode='categorical',
    shuffle=False
)

print("📋 ORDEN REAL DE CLASES:")
print("-" * 60)
for class_name, index in sorted(generator.class_indices.items(), key=lambda x: x[1]):
    print(f"  Índice {index}: {class_name}")
print("-" * 60)

print("\n💡 En Flutter debes mapear así:")
print("-" * 60)

# Crear el mapeo correcto
classes_by_index = {v: k for k, v in generator.class_indices.items()}
for i in range(len(classes_by_index)):
    print(f"  output[0][{i}] = {classes_by_index[i]}Prob;")

print("-" * 60)
print("\n✅ Copia ese orden exacto en ear_validator_service.dart\n")
