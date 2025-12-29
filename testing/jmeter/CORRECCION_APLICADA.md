# Corrección Aplicada - Error de Plugins JMeter

**Fecha:** 23 de diciembre de 2025  
**Archivo corregido:** `BiometricAuth_Stress_Test.jmx`

---

## ✅ Problema Resuelto

### Error Original:
```
CannotResolveClassException: kg.apc.jmeter.vizualizers.CorrectedResultCollector
path: /jmeterTestPlan/hashTree/hashTree/kg.apc.jmeter.vizualizers.CorrectedResultCollector
line number: 540
```

### Solución Aplicada:

**Removido el componente "Active Threads Over Time"** (líneas 540-581) del archivo `BiometricAuth_Stress_Test.jmx`

Este componente requería el plugin `kg.apc` (JMeter Plugins) que no está instalado.

---

## 📊 Impacto

### ❌ Perdido:
- Gráfico "Active Threads Over Time" (visualización avanzada de hilos activos)

### ✅ Mantenido:
- Todas las pruebas de estrés funcionan normalmente
- Aggregate Report (resumen de métricas)
- View Results Tree (resultados detallados)
- Summary Report (reporte resumido)
- Simple Data Writer (archivos .jtl para análisis posterior)
- Generación de reportes HTML con `-e -o report/`

---

## 🚀 Cómo Ejecutar Ahora

### Opción 1: Desde el menú interactivo
```bash
.\run_all_tests.bat
# Seleccionar opción 2 (SPIKE TEST)
```

### Opción 2: Directamente desde línea de comandos
```bash
jmeter -n -t BiometricAuth_Stress_Test.jmx -l results_stress.jtl -e -o report_stress/
```

### Opción 3: Ver solo en GUI (sin ejecutar)
```bash
jmeter -t BiometricAuth_Stress_Test.jmx
```

---

## 📈 Métricas Disponibles

Después de ejecutar la prueba, tendrás acceso a:

1. **Archivo .jtl con datos raw**
   - `results_stress.jtl`

2. **Reporte HTML completo** (si usas `-e -o report/`)
   - Dashboard con gráficos
   - Statistics (avg, min, max, p90, p95, p99)
   - Throughput over time
   - Response time percentiles
   - Error rate

3. **Métricas en consola:**
   - Summary report al final de la ejecución

---

## 🔧 Alternativa: Instalar Plugins (Opcional)

Si en el futuro quieres los gráficos avanzados:

1. **Descargar JMeter Plugins Manager:**
   ```
   https://jmeter-plugins.org/get/
   ```

2. **Copiar a JMeter:**
   ```bash
   copy jmeter-plugins-manager.jar %JMETER_HOME%\lib\ext\
   ```

3. **Abrir JMeter GUI y instalar:**
   - Options → Plugins Manager
   - Available Plugins → Custom Thread Groups
   - Apply Changes and Restart

---

## ✅ Estado Actual

**Archivo:** `BiometricAuth_Stress_Test.jmx`  
**Estado:** ✅ Funcional (sin dependencias de plugins externos)  
**Listeners disponibles:** Estándar de JMeter (suficiente para tesis)  
**Siguiente paso:** Ejecutar `run_all_tests.bat` opción 2

---

**¡El archivo ya está corregido y listo para usar!** 🎯
