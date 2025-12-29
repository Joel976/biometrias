#!/bin/bash
# ============================================================
# Quick Start - JMeter BiometricAuth
# ============================================================

echo ""
echo "============================================================"
echo "  QUICK START - JMETER BIOMETRICAUTH"
echo "============================================================"
echo ""

# Verificar JMeter
if ! command -v jmeter &> /dev/null; then
    echo "[ERROR] JMeter no está instalado"
    echo ""
    echo "Instalación rápida:"
    echo ""
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS detectado - Usando Homebrew:"
        echo "  brew install jmeter"
        read -p "¿Instalar ahora? (s/n): " install_now
        if [[ "$install_now" =~ ^[sS]$ ]]; then
            brew install jmeter
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Linux detectado:"
        echo "  Ubuntu/Debian: sudo apt-get install jmeter"
        echo "  Fedora/RHEL: sudo dnf install jmeter"
        read -p "¿Instalar con apt-get ahora? (s/n): " install_now
        if [[ "$install_now" =~ ^[sS]$ ]]; then
            sudo apt-get update && sudo apt-get install -y jmeter
        fi
    fi
    
    if ! command -v jmeter &> /dev/null; then
        echo ""
        echo "Por favor instala JMeter manualmente y vuelve a ejecutar este script"
        exit 1
    fi
fi

echo "[OK] JMeter detectado:"
jmeter -v | grep "Version"
echo ""

# Verificar conectividad con backend
echo "Verificando conectividad con backend..."
if curl -s --max-time 5 http://192.168.100.197:3000/api/health > /dev/null 2>&1; then
    echo "[OK] Backend responde correctamente"
else
    echo "[ERROR] No se puede conectar al backend en http://192.168.100.197:3000"
    echo ""
    echo "Verifica que:"
    echo "1. El servidor backend esté corriendo"
    echo "2. La dirección IP sea correcta"
    echo "3. El firewall permita la conexión"
    echo ""
    read -p "¿Continuar de todas formas? (s/n): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[sS]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "============================================================"
echo "  INICIO RÁPIDO - SELECCIONA UNA OPCIÓN"
echo "============================================================"
echo ""
echo "1. Prueba Rápida (GUI) - 10 usuarios, 1 minuto"
echo "2. Prueba Estándar (NO-GUI) - 100 usuarios, 5 minutos"
echo "3. Abrir Suite Completa (Menú Principal)"
echo "4. Ver Documentación"
echo "0. Salir"
echo ""

read -p "Opción (0-4): " quick_choice

case $quick_choice in
    0)
        exit 0
        ;;
    1)
        echo ""
        echo "Abriendo JMeter en modo GUI..."
        echo "IMPORTANTE: Prueba de demostración con 10 usuarios"
        echo ""
        jmeter -t BiometricAuth_Backend_Load_Test.jmx &
        echo ""
        echo "JMeter abierto. Haz clic en el botón verde START (▶) para iniciar."
        echo ""
        ;;
    2)
        echo ""
        echo "Ejecutando prueba estándar (100 usuarios, 5 minutos)..."
        echo ""
        
        mkdir -p results
        timestamp=$(date +"%Y%m%d_%H%M%S")
        
        jmeter -n -t BiometricAuth_Backend_Load_Test.jmx \
               -l "results/quick_test_${timestamp}.jtl" \
               -e -o "results/quick_test_report_${timestamp}"
        
        echo ""
        echo "============================================================"
        echo "  PRUEBA COMPLETADA"
        echo "============================================================"
        echo ""
        echo "Resultados en: results/quick_test_report_${timestamp}/index.html"
        echo ""
        read -p "¿Deseas abrir el reporte en el navegador? (s/n): " open_report
        
        if [[ "$open_report" =~ ^[sS]$ ]]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                open "results/quick_test_report_${timestamp}/index.html"
            elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                xdg-open "results/quick_test_report_${timestamp}/index.html" 2>/dev/null || \
                firefox "results/quick_test_report_${timestamp}/index.html" 2>/dev/null || \
                echo "Abre manualmente: results/quick_test_report_${timestamp}/index.html"
            fi
        fi
        ;;
    3)
        echo ""
        echo "Abriendo suite completa de pruebas..."
        chmod +x run_all_tests.sh
        ./run_all_tests.sh
        ;;
    4)
        echo ""
        echo "Abriendo documentación..."
        if [ -f "JMETER_IMPLEMENTACION.md" ]; then
            if command -v mdless &> /dev/null; then
                mdless JMETER_IMPLEMENTACION.md
            elif command -v less &> /dev/null; then
                less JMETER_IMPLEMENTACION.md
            else
                cat JMETER_IMPLEMENTACION.md
            fi
        else
            echo "ERROR: No se encuentra JMETER_IMPLEMENTACION.md"
        fi
        ;;
    *)
        echo "Opción inválida"
        exit 1
        ;;
esac

echo ""
echo "Script finalizado"
exit 0
