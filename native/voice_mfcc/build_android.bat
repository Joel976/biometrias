@echo off
REM Script para compilar libvoice_mfcc.so para Android en Windows
REM Requiere Android NDK instalado

setlocal enabledelayedexpansion

echo.
echo ============================================
echo  Compilando libvoice_mfcc.so para Android
echo ============================================
echo.

REM Verificar que ANDROID_NDK esté configurado
if "%ANDROID_NDK%"=="" (
    echo [ERROR] Variable ANDROID_NDK no esta configurada
    echo.
    echo Por favor, instala Android NDK y configura la variable de entorno:
    echo   set ANDROID_NDK=C:\path\to\android-ndk
    echo.
    echo O descarga desde: https://developer.android.com/ndk/downloads
    echo.
    pause
    exit /b 1
)

echo [INFO] NDK: %ANDROID_NDK%
echo.

REM Configurar rutas
set SCRIPT_DIR=%~dp0
set BUILD_DIR=%SCRIPT_DIR%build
set OUTPUT_DIR=%SCRIPT_DIR%..\..\mobile_app\android\app\src\main\jniLibs

REM Verificar que exista CMake
where cmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] CMake no esta instalado
    echo.
    echo Descarga e instala CMake desde: https://cmake.org/download/
    echo O instala via Chocolatey: choco install cmake
    echo.
    pause
    exit /b 1
)

echo [INFO] CMake encontrado
echo.

REM Arquitecturas a compilar
set ARCHS=arm64-v8a armeabi-v7a x86_64

for %%A in (%ARCHS%) do (
    echo.
    echo [BUILD] Compilando para %%A...
    echo.
    
    REM Crear directorio de build
    set ARCH_BUILD_DIR=%BUILD_DIR%\%%A
    if not exist "!ARCH_BUILD_DIR!" mkdir "!ARCH_BUILD_DIR!"
    
    cd /d "!ARCH_BUILD_DIR!"
    
    REM Configurar CMake con Android NDK
    cmake ^
        -DCMAKE_TOOLCHAIN_FILE=%ANDROID_NDK%\build\cmake\android.toolchain.cmake ^
        -DANDROID_ABI=%%A ^
        -DANDROID_PLATFORM=android-21 ^
        -DANDROID_NDK=%ANDROID_NDK% ^
        -DCMAKE_BUILD_TYPE=Release ^
        -G "Ninja" ^
        "%SCRIPT_DIR%"
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Fallo la configuracion de CMake para %%A
        cd /d "%SCRIPT_DIR%"
        pause
        exit /b 1
    )
    
    REM Compilar
    cmake --build . --config Release
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Fallo la compilacion para %%A
        cd /d "%SCRIPT_DIR%"
        pause
        exit /b 1
    )
    
    REM Copiar librería al proyecto Flutter
    if not exist "%OUTPUT_DIR%\%%A" mkdir "%OUTPUT_DIR%\%%A"
    copy /Y libvoice_mfcc.so "%OUTPUT_DIR%\%%A\" >nul
    
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] No se pudo copiar la libreria para %%A
        cd /d "%SCRIPT_DIR%"
        pause
        exit /b 1
    )
    
    echo [SUCCESS] Libreria compilada y copiada a %OUTPUT_DIR%\%%A\
    
    cd /d "%SCRIPT_DIR%"
)

echo.
echo ============================================
echo  Compilacion completada exitosamente!
echo ============================================
echo.
echo Librerias generadas:
dir /b "%OUTPUT_DIR%\*\*.so"
echo.
echo Ahora puedes ejecutar en mobile_app:
echo   flutter clean
echo   flutter build apk
echo.
pause
