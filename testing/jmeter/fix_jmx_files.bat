@echo off
REM ============================================================
REM SOLUCION RAPIDA: Remover visualizadores problematicos
REM ============================================================

echo.
echo ========================================
echo   LIMPIANDO ARCHIVOS JMETER
echo ========================================
echo.

REM Hacer backup
echo Creando backup de archivos originales...
copy /Y BiometricAuth_Stress_Test.jmx BiometricAuth_Stress_Test.jmx.backup >nul 2>&1
copy /Y BiometricAuth_Backend_Load_Test.jmx BiometricAuth_Backend_Load_Test.jmx.backup >nul 2>&1

echo Backups creados (.jmx.backup)
echo.

REM Remover referencias a plugins de kg.apc usando PowerShell
echo Removiendo referencias a plugins faltantes...

powershell -Command "(Get-Content 'BiometricAuth_Stress_Test.jmx') -replace '<kg\.apc\.jmeter\.vizualizers\.CorrectedResultCollector.*?</kg\.apc\.jmeter\.vizualizers\.CorrectedResultCollector>', '' -replace '<hashTree>\s*</hashTree>', '' | Set-Content 'BiometricAuth_Stress_Test_Fixed.jmx'"

powershell -Command "(Get-Content 'BiometricAuth_Backend_Load_Test.jmx') -replace '<kg\.apc\.jmeter\.vizualizers\.CorrectedResultCollector.*?</kg\.apc\.jmeter\.vizualizers\.CorrectedResultCollector>', '' -replace '<hashTree>\s*</hashTree>', '' | Set-Content 'BiometricAuth_Backend_Load_Test_Fixed.jmx'"

echo.
echo ========================================
echo   ARCHIVOS CORREGIDOS
echo ========================================
echo.
echo - BiometricAuth_Stress_Test_Fixed.jmx
echo - BiometricAuth_Backend_Load_Test_Fixed.jmx
echo.
echo Ahora puedes ejecutar las pruebas con estos archivos corregidos
echo.

pause
