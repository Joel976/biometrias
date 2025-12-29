#!/bin/bash
# ============================================================
# Script de ejecución de pruebas JMeter para BiometricAuth
# ============================================================

echo ""
echo "============================================================"
echo "  BIOMETRICAUTH - SUITE DE PRUEBAS DE RENDIMIENTO"
echo "============================================================"
echo ""

# Verificar que JMeter esté instalado
if ! command -v jmeter &> /dev/null; then
    echo "ERROR: JMeter no está instalado o no está en el PATH"
    echo ""
    echo "Instalación en Linux/Mac:"
    echo "1. Ubuntu/Debian: sudo apt-get install jmeter"
    echo "2. Mac (Homebrew): brew install jmeter"
    echo "3. Manual: Descarga desde https://jmeter.apache.org/download_jmeter.cgi"
    echo ""
    exit 1
fi

# Crear directorio de resultados
mkdir -p results

echo ""
echo "Selecciona el tipo de prueba a ejecutar:"
echo ""
echo "1. Prueba de Carga Backend (100 usuarios, 5 minutos)"
echo "2. Prueba de Estrés - SPIKE TEST (1000 usuarios, 3 minutos)"
echo "3. Prueba de Estrés - SOAK TEST (200 usuarios, 2 horas)"
echo "4. Prueba de Estrés - BREAKPOINT TEST (2000 usuarios progresivos)"
echo "5. TODAS LAS PRUEBAS (Secuencial)"
echo "6. Modo NO-GUI - Reporte HTML Completo"
echo "0. Salir"
echo ""

read -p "Ingresa tu opción (0-6): " choice

load_test() {
    echo ""
    echo "============================================================"
    echo "  EJECUTANDO: PRUEBA DE CARGA BACKEND"
    echo "============================================================"
    echo ""
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    jmeter -n -t BiometricAuth_Backend_Load_Test.jmx \
           -l "results/load_test_${timestamp}.jtl" \
           -e -o "results/load_test_report_${timestamp}"
    
    echo ""
    echo "Prueba completada. Revisa results/load_test_report_${timestamp}/index.html"
}

spike_test() {
    echo ""
    echo "============================================================"
    echo "  EJECUTANDO: SPIKE TEST (Pico Extremo - 1000 usuarios)"
    echo "============================================================"
    echo ""
    echo "ADVERTENCIA: Esta prueba generará carga extrema en el servidor"
    read -p "¿Deseas continuar? (s/n): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        return 0
    fi
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    jmeter -n -t BiometricAuth_Stress_Test.jmx \
           -l "results/spike_test_${timestamp}.jtl" \
           -e -o "results/spike_test_report_${timestamp}"
    
    echo ""
    echo "Prueba completada. Revisa results/spike_test_report_${timestamp}/index.html"
}

soak_test() {
    echo ""
    echo "============================================================"
    echo "  EJECUTANDO: SOAK TEST (Resistencia - 2 horas)"
    echo "============================================================"
    echo ""
    echo "ADVERTENCIA: Esta prueba durará 2 horas"
    read -p "¿Deseas continuar? (s/n): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        return 0
    fi
    
    echo ""
    echo "IMPORTANTE: Asegúrate de habilitar el ThreadGroup 'SOAK TEST' en el archivo .jmx"
    echo "(Cambia enabled='false' a enabled='true' en la línea correspondiente)"
    read -p "Presiona ENTER para continuar..."
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    jmeter -n -t BiometricAuth_Stress_Test.jmx \
           -l "results/soak_test_${timestamp}.jtl" \
           -e -o "results/soak_test_report_${timestamp}"
    
    echo ""
    echo "Prueba completada. Revisa results/soak_test_report_${timestamp}/index.html"
}

breakpoint_test() {
    echo ""
    echo "============================================================"
    echo "  EJECUTANDO: BREAKPOINT TEST (Punto de Quiebre - 2000 usuarios)"
    echo "============================================================"
    echo ""
    echo "ADVERTENCIA: Esta prueba buscará el punto de falla del sistema"
    read -p "¿Deseas continuar? (s/n): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        return 0
    fi
    
    echo ""
    echo "IMPORTANTE: Asegúrate de habilitar el ThreadGroup 'BREAKPOINT TEST' en el archivo .jmx"
    read -p "Presiona ENTER para continuar..."
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    jmeter -n -t BiometricAuth_Stress_Test.jmx \
           -l "results/breakpoint_test_${timestamp}.jtl" \
           -e -o "results/breakpoint_test_report_${timestamp}"
    
    echo ""
    echo "Prueba completada. Revisa results/breakpoint_test_report_${timestamp}/index.html"
}

all_tests() {
    echo ""
    echo "============================================================"
    echo "  EJECUTANDO TODAS LAS PRUEBAS SECUENCIALMENTE"
    echo "============================================================"
    echo ""
    echo "ADVERTENCIA: Esto ejecutará todas las pruebas de forma secuencial"
    echo "Tiempo estimado: 3+ horas"
    read -p "¿Deseas continuar? (s/n): " confirm
    
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        return 0
    fi
    
    echo ""
    echo "[1/3] Ejecutando Prueba de Carga..."
    load_test
    
    echo ""
    echo "[2/3] Ejecutando Spike Test..."
    spike_test
    
    echo ""
    echo "[3/3] Esperando 5 minutos antes del Breakpoint Test..."
    sleep 300
    
    breakpoint_test
    
    echo ""
    echo "============================================================"
    echo "  TODAS LAS PRUEBAS COMPLETADAS"
    echo "============================================================"
}

nogui_test() {
    echo ""
    echo "============================================================"
    echo "  MODO NO-GUI - REPORTE HTML COMPLETO"
    echo "============================================================"
    echo ""
    echo "Selecciona la prueba:"
    echo "1. Backend Load Test"
    echo "2. Stress Test"
    echo ""
    read -p "Opción (1-2): " testchoice
    
    if [ "$testchoice" == "1" ]; then
        testfile="BiometricAuth_Backend_Load_Test.jmx"
        testname="backend_load"
    elif [ "$testchoice" == "2" ]; then
        testfile="BiometricAuth_Stress_Test.jmx"
        testname="stress"
    else
        echo "Opción inválida"
        return 1
    fi
    
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    echo ""
    echo "Ejecutando ${testfile} en modo NO-GUI..."
    echo ""
    
    jmeter -n -t "${testfile}" \
           -l "results/${testname}_${timestamp}.jtl" \
           -j "results/${testname}_${timestamp}.log" \
           -e -o "results/${testname}_html_report_${timestamp}"
    
    echo ""
    echo "============================================================"
    echo "  PRUEBA COMPLETADA"
    echo "============================================================"
    echo ""
    echo "Resultados guardados en:"
    echo "  - JTL: results/${testname}_${timestamp}.jtl"
    echo "  - Log: results/${testname}_${timestamp}.log"
    echo "  - HTML: results/${testname}_html_report_${timestamp}/index.html"
    echo ""
    echo "Abre el reporte HTML en tu navegador para ver resultados detallados"
    echo ""
}

case $choice in
    0)
        exit 0
        ;;
    1)
        load_test
        ;;
    2)
        spike_test
        ;;
    3)
        soak_test
        ;;
    4)
        breakpoint_test
        ;;
    5)
        all_tests
        ;;
    6)
        nogui_test
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

echo ""
echo "Script finalizado"
exit 0
