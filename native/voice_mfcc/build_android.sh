#!/bin/bash

# Script para compilar libvoice_mfcc.so para Android
# Requiere Android NDK instalado

set -e

# Configurar rutas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DIR="$SCRIPT_DIR/../../mobile_app/android/app/src/main/jniLibs"

# Verificar que NDK esté instalado
if [ -z "$ANDROID_NDK" ]; then
    echo "❌ ERROR: Variable ANDROID_NDK no está configurada"
    echo "Por favor, instala Android NDK y configura la variable de entorno:"
    echo "  export ANDROID_NDK=/path/to/android-ndk"
    exit 1
fi

echo "🔨 Compilando libvoice_mfcc.so para Android..."
echo "📁 NDK: $ANDROID_NDK"

# Arquitecturas a compilar
ARCHS=("arm64-v8a" "armeabi-v7a" "x86_64")
ABI_MAP=("aarch64-linux-android" "armv7a-linux-androideabi" "x86_64-linux-android")
MIN_SDK=21

# Compilar para cada arquitectura
for i in "${!ARCHS[@]}"; do
    ARCH="${ARCHS[$i]}"
    ABI="${ABI_MAP[$i]}"
    
    echo ""
    echo "🔧 Compilando para $ARCH..."
    
    # Crear directorio de build
    ARCH_BUILD_DIR="$BUILD_DIR/$ARCH"
    mkdir -p "$ARCH_BUILD_DIR"
    cd "$ARCH_BUILD_DIR"
    
    # Configurar CMake con Android NDK
    cmake \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="android-$MIN_SDK" \
        -DANDROID_NDK="$ANDROID_NDK" \
        -DCMAKE_BUILD_TYPE=Release \
        "$SCRIPT_DIR"
    
    # Compilar
    cmake --build . --config Release
    
    # Copiar librería al proyecto Flutter
    mkdir -p "$OUTPUT_DIR/$ARCH"
    cp libvoice_mfcc.so "$OUTPUT_DIR/$ARCH/"
    
    echo "✅ Librería compilada y copiada a $OUTPUT_DIR/$ARCH/"
done

echo ""
echo "✅ Compilación completada exitosamente para todas las arquitecturas"
echo ""
echo "📋 Librerías generadas:"
ls -lh "$OUTPUT_DIR"/*/*.so

echo ""
echo "🎉 Listo! Ahora puedes ejecutar 'flutter clean && flutter build apk' en mobile_app/"
