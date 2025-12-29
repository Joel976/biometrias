@echo off
setlocal EnableDelayedExpansion

REM ============================================================
REM Script de ejecución de pruebas JMeter para BiometricAuth
REM ============================================================

echo.
echo ============================================================
echo   BIOMETRICAUTH - SUITE DE PRUEBAS DE RENDIMIENTO
echo ============================================================
echo.

REM ------------------------------------------------------------
REM Verificar que JMeter esté instalado y en el PATH
REM ------------------------------------------------------------
where jmeter >nul 2>nul
if errorlevel 1 (
    echo ERROR: JMeter no esta instalado o no esta en el PATH
    echo.
    echo Pasos:
    echo 1. Descarga JMeter desde la web oficial
    echo 2. Extrae en C:\apache-jmeter-5.6.3
    echo 3. Agrega C:\apache-jmeter-5.6.3\bin al PATH
    echo.
    pause
    exit /b 1
)

REM ------------------------------------------------------------
REM Crear directorios necesarios
REM ------------------------------------------------------------
if not exist "results" mkdir results
if not exist "reports" mkdir reports

REM ------------------------------------------------------------
REM Menu principal
REM ------------------------------------------------------------
echo.
echo Selecciona el tipo de prueba a ejecutar:
echo.
echo 1. Prueba de Carga Backend (100 usuarios, 5 minutos)
echo 2. Prueba de Estres - SPIKE TEST (1000 usuarios)
echo 3. Prueba de Estres - SOAK TEST (2 horas)
echo 4. Prueba de Estres - BREAKPOINT TEST
echo 5. TODAS LAS PRUEBAS (Secuencial)
echo 6. Modo NO-GUI - Reporte HTML
echo 0. Salir
echo.

set /p choice="Ingresa tu opcion (0-6): "

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto load_test
if "%choice%"=="2" goto spike_test
if "%choice%"=="3" goto soak_test
if "%choice%"=="4" goto breakpoint_test
if "%choice%"=="5" goto all_tests
if "%choice%"=="6" goto nogui_test

echo Opcion invalida
pause
exit /b 1

REM ============================================================
REM FUNCION: Generar TIMESTAMP seguro
REM ============================================================
:make_timestamp
set TIMESTAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%_%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%
set TIMESTAMP=!TIMESTAMP: =0!
exit /b 0

REM ============================================================
REM PRUEBA 1: LOAD TEST
REM ============================================================
:load_test
call :make_timestamp

echo.
echo ============================================================
echo   EJECUTANDO: PRUEBA DE CARGA BACKEND
echo ============================================================
echo.

jmeter -n ^
 -t BiometricAuth_Backend_Load_Test.jmx ^
 -l results\load_test_!TIMESTAMP!.jtl ^
 -e -o reports\load_test_!TIMESTAMP!

echo.
echo Prueba completada
echo Reporte: reports\load_test_!TIMESTAMP!\index.html
pause
exit /b 0

REM ============================================================
REM PRUEBA 2: SPIKE TEST
REM ============================================================
:spike_test
call :make_timestamp

echo.
echo ============================================================
echo   EJECUTANDO: SPIKE TEST (1000 usuarios)
echo ============================================================
echo.
set /p confirm="¿Deseas continuar? (S/N): "
if /i not "!confirm!"=="S" exit /b 0

jmeter -n ^
 -t BiometricAuth_Stress_Test.jmx ^
 -l results\spike_test_!TIMESTAMP!.jtl ^
 -e -o reports\spike_test_!TIMESTAMP!

echo.
echo Prueba completada
echo Reporte: reports\spike_test_!TIMESTAMP!\index.html
pause
exit /b 0

REM ============================================================
REM PRUEBA 3: SOAK TEST
REM ============================================================
:soak_test
call :make_timestamp

echo.
echo ============================================================
echo   EJECUTANDO: SOAK TEST (2 horas)
echo ============================================================
echo.
echo IMPORTANTE:
echo - Habilita el Thread Group "SOAK TEST" en el archivo JMX
pause

jmeter -n ^
 -t BiometricAuth_Stress_Test.jmx ^
 -l results\soak_test_!TIMESTAMP!.jtl ^
 -e -o reports\soak_test_!TIMESTAMP!

echo.
echo Prueba completada
echo Reporte: reports\soak_test_!TIMESTAMP!\index.html
pause
exit /b 0

REM ============================================================
REM PRUEBA 4: BREAKPOINT TEST
REM ============================================================
:breakpoint_test
call :make_timestamp

echo.
echo ============================================================
echo   EJECUTANDO: BREAKPOINT TEST
echo ============================================================
echo.
set /p confirm="¿Deseas continuar? (S/N): "
if /i not "!confirm!"=="S" exit /b 0

jmeter -n ^
 -t BiometricAuth_Stress_Test.jmx ^
 -l results\breakpoint_test_!TIMESTAMP!.jtl ^
 -e -o reports\breakpoint_test_!TIMESTAMP!

echo.
echo Prueba completada
echo Reporte: reports\breakpoint_test_!TIMESTAMP!\index.html
pause
exit /b 0

REM ============================================================
REM TODAS LAS PRUEBAS
REM ============================================================
:all_tests
echo.
echo ============================================================
echo   EJECUTANDO TODAS LAS PRUEBAS
echo ============================================================
echo.

call :load_test
call :spike_test
call :breakpoint_test

echo.
echo TODAS LAS PRUEBAS COMPLETADAS
pause
exit /b 0

REM ============================================================
REM MODO NO-GUI MANUAL
REM ============================================================
:nogui_test
call :make_timestamp

echo.
echo ============================================================
echo   MODO NO-GUI - REPORTE HTML
echo ============================================================
echo.
echo 1. Backend Load Test
echo 2. Stress Test
echo.

set /p testchoice="Opcion (1-2): "

if "%testchoice%"=="1" (
    set TESTFILE=BiometricAuth_Backend_Load_Test.jmx
    set TESTNAME=backend_load
) else if "%testchoice%"=="2" (
    set TESTFILE=BiometricAuth_Stress_Test.jmx
    set TESTNAME=stress
) else (
    echo Opcion invalida
    pause
    exit /b 1
)

jmeter -n ^
 -t !TESTFILE! ^
 -l results\!TESTNAME!_!TIMESTAMP!.jtl ^
 -j results\!TESTNAME!_!TIMESTAMP!.log ^
 -e -o reports\!TESTNAME!_!TIMESTAMP!

echo.
echo ============================================================
echo   PRUEBA COMPLETADA
echo ============================================================
echo.
echo JTL: results\!TESTNAME!_!TIMESTAMP!.jtl
echo LOG: results\!TESTNAME!_!TIMESTAMP!.log
echo HTML: reports\!TESTNAME!_!TIMESTAMP!\index.html
pause
exit /b 0
