@echo off
REM ============================================================
REM Script para corregir el error de plugins faltantes en JMeter
REM ============================================================

echo.
echo ========================================
echo   SOLUCION DE PLUGINS FALTANTES
echo ========================================
echo.

REM Verificar JMETER_HOME
if "%JMETER_HOME%"=="" (
    echo ERROR: Variable JMETER_HOME no esta definida
    echo.
    echo Por favor, define JMETER_HOME con la ruta de instalacion de JMeter
    echo Ejemplo: set JMETER_HOME=C:\apache-jmeter-5.6.3
    pause
    exit /b 1
)

echo JMETER_HOME detectado: %JMETER_HOME%
echo.

REM Copiar Plugins Manager a la carpeta lib/ext de JMeter
echo Copiando JMeter Plugins Manager...
copy /Y jmeter-plugins-manager.jar "%JMETER_HOME%\lib\ext\" >nul 2>&1

if errorlevel 1 (
    echo ERROR: No se pudo copiar el archivo. Verifique permisos.
    pause
    exit /b 1
)

echo OK - Plugins Manager copiado
echo.

echo ========================================
echo   SIGUIENTE PASO (MANUAL)
echo ========================================
echo.
echo 1. Abre JMeter en modo GUI:
echo    %JMETER_HOME%\bin\jmeter.bat
echo.
echo 2. Ve a: Options ^> Plugins Manager
echo.
echo 3. En la pestana "Available Plugins", busca e instala:
echo    - Custom Thread Groups
echo    - 3 Basic Graphs
echo    - PerfMon (Servers Performance Monitoring)
echo.
echo 4. Reinicia JMeter
echo.
echo 5. Ejecuta de nuevo: run_all_tests.bat
echo.

pause
