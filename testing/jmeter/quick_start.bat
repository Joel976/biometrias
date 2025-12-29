@echo off
REM ============================================================
REM Quick Start - JMeter BiometricAuth
REM ============================================================

echo.
echo ============================================================
echo   QUICK START - JMETER BIOMETRICAUTH
echo ============================================================
echo.

REM Verificar JMeter
where jmeter >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] JMeter no está instalado
    echo.
    echo Opciones:
    echo 1. Instalación automática (requiere chocolatey)
    echo 2. Ver instrucciones de instalación manual
    echo 3. Salir
    echo.
    set /p install_choice="Selecciona opción (1-3): "
    
    if "!install_choice!"=="1" goto auto_install
    if "!install_choice!"=="2" goto manual_install
    exit /b 1
)

echo [OK] JMeter detectado: 
jmeter -v | findstr "Version"
echo.

REM Verificar conectividad con backend
echo Verificando conectividad con backend...
curl -s http://192.168.100.197:3000/api/health >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] No se puede conectar al backend en http://192.168.100.197:3000
    echo.
    echo Verifica que:
    echo 1. El servidor backend esté corriendo
    echo 2. La dirección IP sea correcta
    echo 3. El firewall permita la conexión
    echo.
    set /p continue_anyway="¿Continuar de todas formas? (S/N): "
    if /i not "!continue_anyway!"=="S" exit /b 1
) else (
    echo [OK] Backend responde correctamente
)

echo.
echo ============================================================
echo   INICIO RÁPIDO - SELECCIONA UNA OPCIÓN
echo ============================================================
echo.
echo 1. Prueba Rápida (GUI) - 10 usuarios, 1 minuto
echo 2. Prueba Estándar (NO-GUI) - 100 usuarios, 5 minutos
echo 3. Abrir Suite Completa (Menú Principal)
echo 4. Ver Documentación
echo 0. Salir
echo.

set /p quick_choice="Opción (0-4): "

if "%quick_choice%"=="0" exit /b 0
if "%quick_choice%"=="1" goto quick_gui
if "%quick_choice%"=="2" goto quick_nogui
if "%quick_choice%"=="3" goto full_suite
if "%quick_choice%"=="4" goto show_docs

echo Opción inválida
pause
exit /b 1

:quick_gui
echo.
echo Abriendo JMeter en modo GUI...
echo IMPORTANTE: Prueba de demostración con 10 usuarios
echo.
start jmeter -t BiometricAuth_Backend_Load_Test.jmx
echo.
echo JMeter abierto. Haz clic en el botón verde START (▶) para iniciar.
echo.
pause
exit /b 0

:quick_nogui
echo.
echo Ejecutando prueba estándar (100 usuarios, 5 minutos)...
echo.

if not exist "results" mkdir results

set timestamp=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set timestamp=%timestamp: =0%

jmeter -n -t BiometricAuth_Backend_Load_Test.jmx ^
       -l results\quick_test_%timestamp%.jtl ^
       -e -o results\quick_test_report_%timestamp%

echo.
echo ============================================================
echo   PRUEBA COMPLETADA
echo ============================================================
echo.
echo Resultados en: results\quick_test_report_%timestamp%\index.html
echo.
echo ¿Deseas abrir el reporte en el navegador?
set /p open_report="(S/N): "
if /i "%open_report%"=="S" start results\quick_test_report_%timestamp%\index.html
echo.
pause
exit /b 0

:full_suite
echo.
echo Abriendo suite completa de pruebas...
call run_all_tests.bat
exit /b 0

:show_docs
echo.
echo Abriendo documentación...
if exist "JMETER_IMPLEMENTACION.md" (
    start JMETER_IMPLEMENTACION.md
) else (
    echo ERROR: No se encuentra JMETER_IMPLEMENTACION.md
)
pause
exit /b 0

:auto_install
echo.
echo Intentando instalación automática con Chocolatey...
echo.
choco install jmeter -y
if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] JMeter instalado correctamente
    echo Reinicia esta ventana de comandos y ejecuta nuevamente
) else (
    echo [ERROR] Falló instalación automática
    goto manual_install
)
pause
exit /b 0

:manual_install
echo.
echo ============================================================
echo   INSTALACIÓN MANUAL DE JMETER
echo ============================================================
echo.
echo 1. Descarga JMeter desde:
echo    https://jmeter.apache.org/download_jmeter.cgi
echo.
echo 2. Extrae el archivo ZIP en C:\
echo    Ejemplo: C:\apache-jmeter-5.6.3\
echo.
echo 3. Agrega al PATH del sistema:
echo    - Win + R ^> sysdm.cpl
echo    - Variables de entorno
echo    - PATH ^> Editar ^> Nuevo
echo    - Agregar: C:\apache-jmeter-5.6.3\bin
echo.
echo 4. Reinicia la terminal y ejecuta: jmeter -v
echo.
pause
exit /b 1
