# Solución: Error de Plugins Faltantes en JMeter

**Fecha:** 23 de diciembre de 2025  
**Error:** `CannotResolveClassException: kg.apc.jmeter.vizualizers.CorrectedResultCollector`

---

## 🔴 Problema

El archivo `BiometricAuth_Stress_Test.jmx` contiene referencias a componentes de visualización que requieren plugins adicionales de JMeter que **NO están instalados** en tu sistema.

### Error Completo:
```
CannotResolveClassException: kg.apc.jmeter.vizualizers.CorrectedResultCollector
path: /jmeterTestPlan/hashTree/hashTree/kg.apc.jmeter.vizualizers.CorrectedResultCollector
line number: 540
```

### Causa:
- Los archivos `.jmx` fueron creados en un JMeter con plugins instalados
- Tu instalación de JMeter NO tiene esos plugins
- JMeter no puede deserializar el XML porque no conoce esas clases

---

## ✅ Soluciones

### **Opción 1: Solución Rápida (Sin instalar plugins)**

**Ventaja:** No requiere instalar nada, funciona inmediatamente

**Pasos:**

1. **Ejecutar el script de limpieza:**
   ```bash
   fix_jmx_files.bat
   ```

2. **Resultado:**
   - Se crean archivos limpios sin los visualizadores problemáticos:
     - `BiometricAuth_Stress_Test_Fixed.jmx`
     - `BiometricAuth_Backend_Load_Test_Fixed.jmx`
   - Backups originales guardados como `.jmx.backup`

3. **Ejecutar pruebas con archivos corregidos:**
   ```bash
   jmeter -n -t BiometricAuth_Stress_Test_Fixed.jmx -l results_stress.jtl
   ```

**Desventaja:** Pierdes algunos gráficos avanzados en los reportes

---

### **Opción 2: Instalar los Plugins Faltantes (Recomendado para uso futuro)**

**Ventaja:** Tendrás todas las funcionalidades de visualización

**Pasos:**

#### 1. Instalar JMeter Plugins Manager

Ya descargamos el archivo `jmeter-plugins-manager.jar`. Ahora:

```bash
# Copiar a la carpeta de plugins de JMeter
copy jmeter-plugins-manager.jar "%JMETER_HOME%\lib\ext\"
```

O ejecutar:
```bash
fix_jmeter_plugins.bat
```

#### 2. Abrir JMeter en modo GUI

```bash
cd %JMETER_HOME%\bin
jmeter.bat
```

#### 3. Instalar Plugins Necesarios

1. En JMeter, ir a: **Options → Plugins Manager**
2. En la pestaña **"Available Plugins"**, buscar e instalar:
   - ✅ **Custom Thread Groups**
   - ✅ **3 Basic Graphs**
   - ✅ **PerfMon (Servers Performance Monitoring)**
   - ✅ **5 Additional Graphs**

3. Click en **"Apply Changes and Restart JMeter"**

#### 4. Verificar Instalación

Después de reiniciar, verifica que puedes abrir los archivos `.jmx` originales:

```bash
jmeter -n -t BiometricAuth_Stress_Test.jmx -l results_test.jtl
```

Si no hay errores, ¡está resuelto! ✅

---

### **Opción 3: Usar JMeter desde Línea de Comandos (Solo métricas básicas)**

Si solo necesitas ejecutar las pruebas y obtener métricas (no gráficos avanzados):

**Comando simplificado:**
```bash
jmeter -n -t BiometricAuth_Stress_Test.jmx -l results.jtl -j jmeter.log
```

**Generar reporte HTML:**
```bash
jmeter -g results.jtl -o report_html/
```

Este método ignora los listeners problemáticos y genera un reporte estándar.

---

## 🛠️ Scripts Creados

### 1. `fix_jmx_files.bat`
Remueve automáticamente los visualizadores problemáticos de los archivos `.jmx`

**Uso:**
```bash
fix_jmx_files.bat
```

**Resultado:**
- Crea versiones "_Fixed.jmx" sin plugins
- Guarda backups de los originales

---

### 2. `fix_jmeter_plugins.bat`
Instala el Plugins Manager en JMeter

**Uso:**
```bash
fix_jmeter_plugins.bat
```

**Requisito:**
- Variable `JMETER_HOME` debe estar definida

---

## 📊 Alternativa: Crear Nuevos Archivos JMeter Sin Plugins

Si prefieres empezar desde cero:

### Crear Test Plan Básico en JMeter GUI:

1. Abrir JMeter GUI
2. Crear Thread Group:
   - Number of Threads: 100
   - Ramp-up: 60s
   - Loop Count: Infinite
   - Duration: 300s

3. Añadir HTTP Request:
   - Server: localhost
   - Port: 3000
   - Path: /api/auth/register
   - Method: POST

4. Añadir Listeners ESTÁNDAR (sin plugins):
   - ✅ Summary Report
   - ✅ View Results Tree
   - ✅ Aggregate Report
   - ✅ Graph Results

5. Guardar como: `BiometricAuth_Test_Simple.jmx`

6. Ejecutar desde terminal:
   ```bash
   jmeter -n -t BiometricAuth_Test_Simple.jmx -l results.jtl -e -o report/
   ```

---

## 🎯 Recomendación

**Para este proyecto de tesis:**

1. **Ejecuta:** `fix_jmx_files.bat`
2. **Usa:** Los archivos `_Fixed.jmx` generados
3. **Genera reportes HTML** con:
   ```bash
   jmeter -n -t BiometricAuth_Stress_Test_Fixed.jmx -l results.jtl -e -o report/
   ```

**Ventajas:**
- ✅ Solución inmediata
- ✅ No requiere instalar nada
- ✅ Reportes HTML funcionan perfectamente
- ✅ Todas las métricas necesarias disponibles

**Para trabajo futuro:**
- Instala los plugins siguiendo **Opción 2**
- Tendrás gráficos más avanzados

---

## 📝 Verificación Post-Solución

Después de aplicar cualquier solución, verifica:

```bash
# Test rápido
jmeter -n -t BiometricAuth_Stress_Test_Fixed.jmx -l test.jtl

# Verificar que no hay errores
type test.jtl
```

**Si ves datos CSV sin errores:** ✅ Problema resuelto

---

## 📚 Referencias

- [JMeter Plugins Manager](https://jmeter-plugins.org/wiki/PluginsManager/)
- [JMeter Non-GUI Mode](https://jmeter.apache.org/usermanual/get-started.html#non_gui)
- [JMeter HTML Reports](https://jmeter.apache.org/usermanual/generating-dashboard.html)

---

**Autor:** Joel976  
**Proyecto:** Sistema de Autenticación Biométrica  
**Versión JMeter:** 5.6.3
