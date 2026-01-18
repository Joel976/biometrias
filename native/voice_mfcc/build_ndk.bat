@echo off
REM Script SIMPLE para compilar libvoice_mfcc.so usando NDK directamente
REM No requiere CMake - usa ndk-build

setlocal enabledelayedexpansion

echo.
echo ============================================
echo  Compilando con ndk-build (metodo simple)
echo ============================================
echo.

REM Verificar ANDROID_NDK
if "%ANDROID_NDK%"=="" (
    echo [ERROR] Variable ANDROID_NDK no configurada
    echo.
    echo Configura la variable:
    echo   set ANDROID_NDK=C:\Users\User\AppData\Local\Android\Sdk\ndk\[version]
    echo.
    pause
    exit /b 1
)

echo [INFO] NDK: %ANDROID_NDK%
echo.

REM Verificar que exista ndk-build
if not exist "%ANDROID_NDK%\ndk-build.cmd" (
    echo [ERROR] ndk-build.cmd no encontrado en %ANDROID_NDK%
    echo.
    echo Verifica que ANDROID_NDK apunte a la carpeta correcta del NDK
    echo.
    pause
    exit /b 1
)

echo [INFO] ndk-build encontrado
echo.

REM Configurar rutas
set SCRIPT_DIR=%~dp0
set JNI_DIR=%SCRIPT_DIR%jni
set OUTPUT_DIR=%SCRIPT_DIR%..\..\mobile_app\android\app\src\main\jniLibs

REM Crear estructura jni/
if not exist "%JNI_DIR%" mkdir "%JNI_DIR%"

REM Crear Android.mk
echo [INFO] Creando Android.mk...
(
echo LOCAL_PATH := $^(call my-dir^)
echo.
echo include $^(CLEAR_VARS^)
echo.
echo LOCAL_MODULE := voice_mfcc
echo LOCAL_SRC_FILES := ../voice_mfcc.cpp
echo LOCAL_LDLIBS := -llog -lm
echo LOCAL_CPPFLAGS := -std=c++11 -Wall
echo.
echo include $^(BUILD_SHARED_LIBRARY^)
) > "%JNI_DIR%\Android.mk"

REM Crear Application.mk
echo [INFO] Creando Application.mk...
(
echo APP_ABI := arm64-v8a armeabi-v7a x86_64
echo APP_PLATFORM := android-21
echo APP_STL := c++_static
echo APP_CPPFLAGS := -std=c++11
) > "%JNI_DIR%\Application.mk"

echo.
echo [BUILD] Compilando con ndk-build...
echo.

REM Compilar
cd /d "%SCRIPT_DIR%"
call "%ANDROID_NDK%\ndk-build.cmd" NDK_PROJECT_PATH=. NDK_APPLICATION_MK=jni/Application.mk

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Fallo la compilacion con ndk-build
    echo.
    pause
    exit /b 1
)

echo.
echo [INFO] Copiando librerias a jniLibs...
echo.

REM Copiar librerías compiladas
xcopy /Y /I "%SCRIPT_DIR%libs\*" "%OUTPUT_DIR%\" /E >nul

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] No se pudieron copiar las librerias
    pause
    exit /b 1
)

echo.
echo ============================================
echo  Compilacion exitosa!
echo ============================================
echo.
echo Librerias generadas en:
dir /s /b "%OUTPUT_DIR%\*.so"
echo.
echo Ahora ejecuta en mobile_app:
echo   flutter clean
echo   flutter build apk
echo.
pause
