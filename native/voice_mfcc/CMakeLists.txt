cmake_minimum_required(VERSION 3.10)

project(voice_mfcc)

# Configuración del estándar C++
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Opciones de optimización
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -ffast-math")

# Crear librería compartida
add_library(voice_mfcc SHARED
    voice_mfcc.cpp
)

# Enlazar con librería matemática
target_link_libraries(voice_mfcc m)

# Configuración de instalación
install(TARGETS voice_mfcc
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
