# CMakeLists.txt para compilación nativa Android/iOS
# Este archivo es usado por Flutter automáticamente cuando compilas la APK
cmake_minimum_required(VERSION 3.10)
project(voz_mobile_flutter LANGUAGES C CXX)

# Configuración C++20
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Detectar plataforma
if(ANDROID)
    message(STATUS "🤖 Compilando para Android (${ANDROID_ABI})")
    set(PLATFORM_NAME "android")
elseif(IOS)
    message(STATUS "🍎 Compilando para iOS")
    set(PLATFORM_NAME "ios")
else()
    message(STATUS "🖥️ Compilando para Desktop")
    set(PLATFORM_NAME "desktop")
endif()

# Directorios
set(VOZ_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
set(MOBILE_DIR "${VOZ_ROOT}/apps/mobile")
set(EXTERNAL_DIR "${VOZ_ROOT}/external")

# ============================================================================
# 1. LIBRERÍA SQLite3 (desde amalgamation)
# ============================================================================
message(STATUS "📦 Compilando SQLite3 amalgamation...")

add_library(sqlite3_local STATIC 
    "${EXTERNAL_DIR}/sqlite3.c"
)

target_include_directories(sqlite3_local PUBLIC 
    "${EXTERNAL_DIR}"
)

target_compile_definitions(sqlite3_local PRIVATE 
    SQLITE_ENABLE_COLUMN_METADATA
    SQLITE_ENABLE_FTS5
    SQLITE_ENABLE_RTREE
    SQLITE_THREADSAFE=1
)

# Optimizaciones para SQLite
if(ANDROID)
    target_compile_options(sqlite3_local PRIVATE 
        -O3 
        -DNDEBUG
    )
endif()

# ============================================================================
# 2. LIBRERÍA VOZ_MOBILE (API móvil)
# ============================================================================
message(STATUS "🎤 Compilando libvoz_mobile...")

# Archivos fuente de la API móvil
set(MOBILE_SOURCES
    "${MOBILE_DIR}/mobile_api.cpp"
    "${MOBILE_DIR}/sqlite_adapter.cpp"
)

# Buscar archivos core (asumiendo que existen en subdirectorios)
file(GLOB_RECURSE CORE_SOURCES 
    "${VOZ_ROOT}/core/*.cpp"
)

file(GLOB_RECURSE UTILS_SOURCES 
    "${VOZ_ROOT}/utils/*.cpp"
)

# Si no hay archivos core, crear stubs
if(NOT CORE_SOURCES)
    message(WARNING "⚠️ No se encontraron archivos en core/ - usando solo mobile_api")
endif()

# Crear librería compartida
add_library(voz_mobile SHARED
    ${MOBILE_SOURCES}
    ${CORE_SOURCES}
    ${UTILS_SOURCES}
)

# Incluir directorios
target_include_directories(voz_mobile PRIVATE
    "${VOZ_ROOT}"
    "${MOBILE_DIR}"
    "${EXTERNAL_DIR}"
    "${VOZ_ROOT}/core"
    "${VOZ_ROOT}/core/preprocessing"
    "${VOZ_ROOT}/core/features"
    "${VOZ_ROOT}/core/classification"
    "${VOZ_ROOT}/utils"
)

# Vincular SQLite
target_link_libraries(voz_mobile PRIVATE 
    sqlite3_local
)

# Configuración específica por plataforma
if(ANDROID)
    # Android: generar libvoz_mobile.so
    set_target_properties(voz_mobile PROPERTIES
        LIBRARY_OUTPUT_NAME "voz_mobile"
        PREFIX "lib"
        SUFFIX ".so"
    )
    
    # Vincular bibliotecas del sistema Android
    target_link_libraries(voz_mobile PRIVATE
        log        # Para __android_log_print
        android    # Para API nativa de Android
    )
    
    # Optimizaciones para Android
    target_compile_options(voz_mobile PRIVATE
        -O3
        -DNDEBUG
        -fvisibility=hidden
        -ffunction-sections
        -fdata-sections
    )
    
    target_link_options(voz_mobile PRIVATE
        -Wl,--gc-sections
        -Wl,--strip-all
    )
    
elseif(IOS)
    # iOS: generar libvoz_mobile.dylib
    set_target_properties(voz_mobile PROPERTIES
        FRAMEWORK TRUE
        FRAMEWORK_VERSION A
        MACOSX_FRAMEWORK_IDENTIFIER com.biometrias.voz_mobile
        LIBRARY_OUTPUT_NAME "voz_mobile"
    )
    
else()
    # Desktop (Windows/Linux/macOS)
    set_target_properties(voz_mobile PROPERTIES
        LIBRARY_OUTPUT_NAME "voz_mobile"
    )
endif()

# Propiedades generales
set_target_properties(voz_mobile PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
    POSITION_INDEPENDENT_CODE ON
    VERSION 1.0.0
    SOVERSION 1
)

# ============================================================================
# 3. INSTALACIÓN (para Flutter)
# ============================================================================
if(ANDROID)
    # Flutter copia automáticamente desde CMAKE_LIBRARY_OUTPUT_DIRECTORY
    install(TARGETS voz_mobile
        LIBRARY DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/${ANDROID_ABI}
    )
    
    message(STATUS "✅ Instalará en: ${CMAKE_INSTALL_PREFIX}/lib/${ANDROID_ABI}")
    
elseif(IOS)
    install(TARGETS voz_mobile
        FRAMEWORK DESTINATION ${CMAKE_INSTALL_PREFIX}
    )
else()
    install(TARGETS voz_mobile
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
    )
endif()

# ============================================================================
# RESUMEN
# ============================================================================
message(STATUS "")
message(STATUS "════════════════════════════════════════")
message(STATUS "  VOZ MOBILE - Configuración Nativa")
message(STATUS "════════════════════════════════════════")
message(STATUS "Plataforma: ${PLATFORM_NAME}")
message(STATUS "Arquitectura: ${CMAKE_SYSTEM_PROCESSOR}")
if(ANDROID)
    message(STATUS "Android ABI: ${ANDROID_ABI}")
    message(STATUS "Android API: ${ANDROID_PLATFORM}")
endif()
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "")
message(STATUS "Librerías:")
message(STATUS "  ✓ sqlite3_local (static)")
message(STATUS "  ✓ voz_mobile (shared)")
message(STATUS "")
message(STATUS "Archivos móviles:")
message(STATUS "  • mobile_api.cpp")
message(STATUS "  • sqlite_adapter.cpp")
if(CORE_SOURCES)
    list(LENGTH CORE_SOURCES CORE_COUNT)
    message(STATUS "  • ${CORE_COUNT} archivos core")
endif()
message(STATUS "════════════════════════════════════════")
message(STATUS "")
