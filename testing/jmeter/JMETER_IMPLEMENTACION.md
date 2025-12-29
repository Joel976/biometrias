# JMETER - IMPLEMENTACIÓN COMPLETA
## Sistema de Pruebas de Rendimiento BiometricAuth

---

## 📋 TABLA DE CONTENIDOS

1. [Introducción](#introducción)
2. [Requisitos Previos](#requisitos-previos)
3. [Instalación de JMeter](#instalación-de-jmeter)
4. [Estructura del Proyecto](#estructura-del-proyecto)
5. [Planes de Prueba Disponibles](#planes-de-prueba-disponibles)
6. [Configuración](#configuración)
7. [Ejecución de Pruebas](#ejecución-de-pruebas)
8. [Interpretación de Resultados](#interpretación-de-resultados)
9. [Métricas Clave](#métricas-clave)
10. [Troubleshooting](#troubleshooting)
11. [Mejores Prácticas](#mejores-prácticas)

---

## 🎯 INTRODUCCIÓN

Este directorio contiene la suite completa de pruebas de rendimiento, estrés y carga para el sistema **BiometricAuth** utilizando **Apache JMeter**.

### Objetivos de las Pruebas

- **Rendimiento**: Medir tiempos de respuesta bajo carga normal
- **Estrés**: Identificar punto de quiebre del sistema
- **Carga**: Validar comportamiento con usuarios concurrentes
- **Resistencia**: Verificar estabilidad en ejecución prolongada

---

## 🔧 REQUISITOS PREVIOS

### Software Necesario

1. **Java JDK 8+**
   ```bash
   # Verificar instalación
   java -version
   ```

2. **Apache JMeter 5.6+**
   - Descarga: https://jmeter.apache.org/download_jmeter.cgi

3. **Servidor Backend Activo**
   - IP: `192.168.100.197`
   - Puerto: `3000`
   - Base de datos PostgreSQL funcionando

### Requisitos de Hardware

- **RAM mínima**: 4 GB (recomendado 8 GB)
- **CPU**: 2+ núcleos
- **Espacio en disco**: 2 GB para resultados

---

## 📦 INSTALACIÓN DE JMETER

### Windows

```powershell
# 1. Descargar JMeter
# Ir a: https://jmeter.apache.org/download_jmeter.cgi
# Descargar: apache-jmeter-5.6.3.zip

# 2. Extraer en C:\
# Resultado: C:\apache-jmeter-5.6.3\

# 3. Agregar al PATH del sistema
setx PATH "%PATH%;C:\apache-jmeter-5.6.3\bin"

# 4. Verificar instalación
jmeter -v
```

### Linux/Ubuntu

```bash
# Opción 1: Instalación via APT
sudo apt-get update
sudo apt-get install jmeter

# Opción 2: Instalación manual
wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.tgz
tar -xzf apache-jmeter-5.6.3.tgz
sudo mv apache-jmeter-5.6.3 /opt/jmeter
echo 'export PATH=$PATH:/opt/jmeter/bin' >> ~/.bashrc
source ~/.bashrc

# Verificar
jmeter -v
```

### macOS

```bash
# Usando Homebrew
brew install jmeter

# Verificar
jmeter -v
```

---

## 📁 ESTRUCTURA DEL PROYECTO

```
testing/jmeter/
│
├── BiometricAuth_Backend_Load_Test.jmx    # Plan de carga backend
├── BiometricAuth_Stress_Test.jmx          # Plan de estrés extremo
├── run_all_tests.bat                       # Script Windows
├── run_all_tests.sh                        # Script Linux/Mac
├── JMETER_IMPLEMENTACION.md                # Esta documentación
│
├── results/                                 # Resultados de pruebas (auto-generado)
│   ├── *.jtl                               # Archivos de datos raw
│   ├── *.log                               # Logs de ejecución
│   └── *_html_report_*/                    # Reportes HTML
│
└── data/                                    # Datos de prueba (opcional)
    ├── usuarios_prueba.csv
    └── api_endpoints.csv
```

---

## 🎯 PLANES DE PRUEBA DISPONIBLES

### 1. **BiometricAuth_Backend_Load_Test.jmx**

**Descripción**: Prueba de carga estándar para el backend

**Configuración**:
- Usuarios concurrentes: 100
- Tiempo de ramp-up: 60 segundos
- Duración total: 5 minutos (300 segundos)

**Escenarios incluidos**:
1. **Registro y Login** (100 usuarios)
   - POST `/api/auth/register`
   - POST `/api/auth/login`
   - Assertions: HTTP 200/201, extracción de token

2. **Verificación Biométrica** (50 usuarios)
   - POST `/api/biometria/verificar-oreja`
   - Assertion: Tiempo de respuesta < 5 segundos

3. **Sincronización** (200 usuarios)
   - POST `/api/sync/descarga`
   - POST `/api/sync/subida`

**Cuándo usar**: Validación de rendimiento normal del sistema

---

### 2. **BiometricAuth_Stress_Test.jmx**

**Descripción**: Suite de pruebas de estrés extremo con 3 escenarios

#### Escenario A: **SPIKE TEST** (Habilitado por defecto)
- **Usuarios**: 0 → 1000 en 60 segundos
- **Duración**: 3 minutos
- **Objetivo**: Evaluar respuesta ante carga súbita
- **Endpoints**: `/api/health`, `/api/auth/login`

#### Escenario B: **SOAK TEST** (Deshabilitado - activar manualmente)
- **Usuarios**: 200 constantes
- **Duración**: 2 horas
- **Objetivo**: Detectar memory leaks, degradación
- **Flujo completo**: Registro → Biometría → Sync

#### Escenario C: **BREAKPOINT TEST** (Deshabilitado - activar manualmente)
- **Usuarios**: 0 → 2000 en 30 minutos
- **Duración**: 1 hora
- **Objetivo**: Encontrar límite de capacidad del sistema
- **Endpoint más pesado**: `/api/biometria/verificar-oreja`

**Cuándo usar**:
- SPIKE: Antes de lanzamiento para validar resistencia
- SOAK: Para certificar estabilidad a largo plazo
- BREAKPOINT: Para planificación de capacidad

---

## ⚙️ CONFIGURACIÓN

### Variables Globales (Editables en los .jmx)

```xml
<!-- En ambos archivos .jmx -->
<elementProp name="SERVER_IP">
  <stringProp name="Argument.value">192.168.100.197</stringProp>
</elementProp>
<elementProp name="SERVER_PORT">
  <stringProp name="Argument.value">3000</stringProp>
</elementProp>
<elementProp name="PROTOCOL">
  <stringProp name="Argument.value">http</stringProp>
</elementProp>
```

### Personalización de Pruebas

#### Cambiar Número de Usuarios (Load Test)

1. Abrir `BiometricAuth_Backend_Load_Test.jmx` en JMeter GUI
2. Navegar: Thread Group → "1. Carga - Registro y Login"
3. Modificar `Number of Threads (users)`: **100** → valor deseado
4. Ajustar `Ramp-Up Period (seconds)` proporcionalmente
5. Guardar archivo

#### Habilitar SOAK/BREAKPOINT Tests

1. Abrir `BiometricAuth_Stress_Test.jmx` en editor de texto
2. Buscar: `testname="SOAK TEST - Resistencia 2h" enabled="false"`
3. Cambiar: `enabled="false"` → `enabled="true"`
4. Guardar archivo

---

## 🚀 EJECUCIÓN DE PRUEBAS

### Método 1: Scripts Automatizados (Recomendado)

#### Windows

```powershell
# Navegar al directorio
cd C:\Users\User\Downloads\biometrias\testing\jmeter

# Ejecutar script
.\run_all_tests.bat
```

**Menú Interactivo**:
```
1. Prueba de Carga Backend (100 usuarios, 5 minutos)
2. Prueba de Estrés - SPIKE TEST (1000 usuarios, 3 minutos)
3. Prueba de Estrés - SOAK TEST (200 usuarios, 2 horas)
4. Prueba de Estrés - BREAKPOINT TEST (2000 usuarios progresivos)
5. TODAS LAS PRUEBAS (Secuencial)
6. Modo NO-GUI - Reporte HTML Completo
0. Salir
```

#### Linux/Mac

```bash
# Navegar al directorio
cd /path/to/biometrias/testing/jmeter

# Dar permisos de ejecución
chmod +x run_all_tests.sh

# Ejecutar script
./run_all_tests.sh
```

---

### Método 2: Línea de Comandos (Avanzado)

#### Ejecución Básica (GUI)

```bash
# Abrir JMeter en modo GUI
jmeter -t BiometricAuth_Backend_Load_Test.jmx
```

**Pasos en GUI**:
1. Hacer clic en botón verde "Start" (▶)
2. Observar métricas en tiempo real
3. Al finalizar, revisar "View Results Tree", "Summary Report"

⚠️ **ADVERTENCIA**: Modo GUI consume muchos recursos. No usar para pruebas grandes.

---

#### Ejecución en Modo NO-GUI (Producción)

```bash
# Prueba de Carga Backend
jmeter -n -t BiometricAuth_Backend_Load_Test.jmx \
       -l results/load_test_$(date +%Y%m%d_%H%M%S).jtl \
       -e -o results/load_test_html_report_$(date +%Y%m%d_%H%M%S)

# Prueba de Estrés (SPIKE)
jmeter -n -t BiometricAuth_Stress_Test.jmx \
       -l results/spike_test_$(date +%Y%m%d_%H%M%S).jtl \
       -e -o results/spike_test_html_report_$(date +%Y%m%d_%H%M%S)
```

**Parámetros**:
- `-n`: Modo NO-GUI
- `-t`: Archivo de plan de prueba (.jmx)
- `-l`: Archivo de resultados (.jtl)
- `-e`: Generar reporte HTML al finalizar
- `-o`: Directorio de salida del reporte HTML

---

### Método 3: Ejecución Remota (Distribuida)

Para pruebas con >1000 usuarios, usar JMeter distribuido:

```bash
# En servidor maestro
jmeter -n -t BiometricAuth_Stress_Test.jmx \
       -R server1,server2,server3 \
       -l results/distributed_test.jtl \
       -e -o results/distributed_report
```

**Configuración**:
1. Editar `jmeter.properties` en todos los servidores
2. Agregar IPs de servidores remotos
3. Iniciar `jmeter-server` en cada nodo remoto

---

## 📊 INTERPRETACIÓN DE RESULTADOS

### Archivos Generados

#### 1. **Archivo .jtl (Raw Data)**

Archivo CSV con datos brutos de cada request:

```csv
timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,failureMessage,bytes,sentBytes,grpThreads,allThreads,URL,Latency,IdleTime,Connect
1704067200000,245,POST /api/auth/login,200,OK,Thread Group 1-1,text,true,,1234,567,100,100,http://192.168.100.197:3000/api/auth/login,230,0,15
```

**Campos clave**:
- `elapsed`: Tiempo de respuesta total (ms)
- `responseCode`: HTTP status (200, 500, etc.)
- `success`: true/false
- `Latency`: Tiempo hasta primer byte

---

#### 2. **Reporte HTML**

Ubicación: `results/*_html_report_*/index.html`

**Secciones principales**:

##### **Dashboard (index.html)**

Métricas resumidas:
- **APDEX (Application Performance Index)**
  - Verde (Satisfactory): < 500ms
  - Amarillo (Tolerating): 500-1500ms
  - Rojo (Frustrated): > 1500ms

- **Requests Summary**
  - Total: Número de requests
  - KO: Requests fallidos
  - OK: Requests exitosos

- **Statistics**
  - Throughput: Requests/segundo
  - Average Response Time: Tiempo promedio
  - Error %: Porcentaje de errores

##### **Charts (content/pages/)**

- `OverTime.html`: Gráficos de tiempo de respuesta
- `ThroughputOverTime.html`: Throughput por segundo
- `ResponseTimesPercentiles.html`: Percentiles 90/95/99
- `TransactionsPerSecond.html`: TPS en el tiempo

---

### Métricas Clave a Analizar

#### 1. **Tiempo de Respuesta (Response Time)**

| Percentil | Valor Objetivo | Interpretación |
|-----------|----------------|----------------|
| 50% (Mediana) | < 500ms | Experiencia típica del usuario |
| 90% | < 1000ms | 90% de usuarios tienen buena experiencia |
| 95% | < 1500ms | Outliers aceptables |
| 99% | < 3000ms | Casos extremos tolerables |

**Acción si excede objetivo**:
- Optimizar queries de base de datos
- Implementar caché Redis
- Escalar horizontalmente

---

#### 2. **Error Rate (Tasa de Errores)**

| Tasa de Error | Estado | Acción Requerida |
|---------------|--------|------------------|
| 0% | Excelente | Ninguna |
| < 1% | Aceptable | Monitorear |
| 1-5% | Advertencia | Investigar logs |
| > 5% | Crítico | Detener producción, corregir |

**Códigos de error comunes**:
- **500**: Error interno del servidor → Revisar logs backend
- **503**: Servicio no disponible → Servidor sobrecargado
- **400/401**: Error de cliente → Revisar datos de prueba

---

#### 3. **Throughput (Rendimiento)**

Requests procesados por segundo:

```
Throughput = Total Requests / Tiempo Total (segundos)
```

**Objetivos BiometricAuth**:
- **Backend normal**: > 50 requests/segundo
- **Pico de carga**: > 200 requests/segundo
- **Verificación biométrica**: > 10 verificaciones/segundo

**Fórmula de capacidad**:
```
Usuarios Soportados = Throughput × Tiempo Promedio por Usuario
```

---

#### 4. **Latencia (Latency)**

Tiempo hasta recibir el primer byte de respuesta:

```
Latencia Total = Network Latency + Server Processing Time
```

**Análisis**:
- Si `Latency ≈ Response Time` → Red es el cuello de botella
- Si `Latency << Response Time` → Procesamiento del servidor es lento

---

### Ejemplo de Análisis Completo

#### Escenario: Prueba de Carga Backend

**Resultados obtenidos**:
```
Total Requests: 15,000
Duration: 300 segundos
Throughput: 50 req/s
Average Response Time: 450ms
Error Rate: 0.2%
```

**Desglose por endpoint**:

| Endpoint | Requests | Avg RT | 95% RT | Error % |
|----------|----------|--------|--------|---------|
| POST /api/auth/register | 5000 | 320ms | 580ms | 0% |
| POST /api/auth/login | 5000 | 250ms | 450ms | 0.1% |
| POST /api/biometria/verificar-oreja | 2500 | 1850ms | 3200ms | 0.5% |
| POST /api/sync/descarga | 2500 | 420ms | 680ms | 0% |

**Análisis**:
✅ **Positivo**:
- Throughput cumple objetivo (50 req/s)
- Error rate aceptable (< 1%)
- Endpoints de autenticación rápidos

⚠️ **Áreas de Mejora**:
- Verificación biométrica lenta (1850ms promedio)
  - **Recomendación**: Implementar procesamiento asíncrono
  - **Recomendación**: Optimizar modelo TensorFlow Lite
  - **Recomendación**: Usar GPU para inferencia

---

## 🎯 MÉTRICAS CLAVE (KPIs)

### KPIs de Rendimiento

| KPI | Objetivo | Crítico |
|-----|----------|---------|
| **Response Time (P95)** | < 1000ms | > 3000ms |
| **Error Rate** | < 1% | > 5% |
| **Throughput** | > 50 req/s | < 20 req/s |
| **Latencia de Red** | < 100ms | > 500ms |
| **Utilización CPU (Backend)** | < 70% | > 90% |
| **Utilización RAM** | < 80% | > 95% |
| **Conexiones DB Activas** | < 50 | > 100 |

### KPIs de Estabilidad

| KPI | Objetivo | Crítico |
|-----|----------|---------|
| **Uptime durante SOAK** | 100% | < 99% |
| **Memory Leak Rate** | 0 MB/hora | > 10 MB/hora |
| **Degradación de RT** | < 10% | > 30% |
| **Recovery Time** | < 30s | > 2 minutos |

---

## 🐛 TROUBLESHOOTING

### Problema 1: Error "java.net.ConnectException: Connection refused"

**Causa**: Backend no está corriendo o firewall bloquea el puerto.

**Solución**:
```bash
# Verificar que backend esté corriendo
curl http://192.168.100.197:3000/api/health

# Si no responde, iniciar backend
cd backend
npm start

# Verificar firewall
sudo ufw status
sudo ufw allow 3000/tcp
```

---

### Problema 2: "OutOfMemoryError: Java heap space"

**Causa**: JMeter se queda sin memoria RAM.

**Solución**:
```bash
# Editar jmeter.bat (Windows) o jmeter (Linux)
# Incrementar heap size:

# Windows (jmeter.bat)
set HEAP=-Xms1g -Xmx4g

# Linux/Mac (jmeter)
HEAP="-Xms1g -Xmx4g"

# Luego reiniciar JMeter
```

---

### Problema 3: "Non HTTP response code: java.net.SocketException"

**Causa**: Demasiadas conexiones simultáneas, servidor rechaza.

**Solución**:
```bash
# Incrementar límite de conexiones en backend (Node.js)
# En backend/src/index.js
server.maxConnections = 5000;

# Incrementar límite del SO (Linux)
sudo sysctl -w net.core.somaxconn=4096
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096

# Windows: Editar registro
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
# MaxUserPort = 65534
```

---

### Problema 4: Resultados inconsistentes entre ejecuciones

**Causa**: Estado del servidor no se limpia entre pruebas.

**Solución**:
```bash
# Script de limpieza pre-test
cd backend

# Limpiar base de datos de pruebas
psql -U postgres -d biometrics_db -c "DELETE FROM usuarios WHERE identificador_unico LIKE 'user_%';"
psql -U postgres -d biometrics_db -c "DELETE FROM usuarios WHERE identificador_unico LIKE 'stress_%';"
psql -U postgres -d biometrics_db -c "DELETE FROM usuarios WHERE identificador_unico LIKE 'soak_%';"

# Reiniciar servicios
pm2 restart biometrics-backend

# Esperar 10 segundos antes de iniciar prueba
sleep 10
```

---

### Problema 5: Reportes HTML no se generan

**Causa**: Errores en archivo .jtl o falta de espacio en disco.

**Solución**:
```bash
# Verificar espacio en disco
df -h

# Generar reporte manualmente desde .jtl existente
jmeter -g results/load_test_20250101_120000.jtl \
       -o results/manual_report_$(date +%Y%m%d_%H%M%S)

# Si falla, revisar logs
tail -f jmeter.log
```

---

## 💡 MEJORES PRÁCTICAS

### 1. **Preparación Pre-Prueba**

✅ **Checklist**:
- [ ] Backend en estado limpio (sin datos de pruebas previas)
- [ ] Base de datos optimizada (VACUUM, ANALYZE)
- [ ] Monitoreo activo (htop, New Relic, Datadog)
- [ ] Notificaciones de equipo (Slack, email)
- [ ] Backup reciente de BD
- [ ] Ventana de mantenimiento programada

```bash
# Script de preparación
#!/bin/bash
echo "=== PRE-TEST CHECKLIST ==="

# 1. Backup BD
pg_dump biometrics_db > backup_pre_test_$(date +%Y%m%d).sql

# 2. Limpiar datos de prueba
psql -U postgres -d biometrics_db -f cleanup_test_data.sql

# 3. Optimizar BD
psql -U postgres -d biometrics_db -c "VACUUM ANALYZE;"

# 4. Reiniciar backend
pm2 restart biometrics-backend

# 5. Verificar salud
curl http://192.168.100.197:3000/api/health

echo "=== LISTO PARA PRUEBAS ==="
```

---

### 2. **Durante la Ejecución**

✅ **Monitoreo Activo**:
```bash
# Terminal 1: Monitoreo de recursos
htop

# Terminal 2: Logs de backend
tail -f backend/logs/app.log

# Terminal 3: Conexiones de BD
watch -n 2 'psql -U postgres -d biometrics_db -c "SELECT count(*) FROM pg_stat_activity;"'

# Terminal 4: JMeter
jmeter -n -t BiometricAuth_Backend_Load_Test.jmx -l results/test.jtl
```

✅ **Indicadores de Problema**:
- CPU sostenida > 90% por > 5 minutos
- Memoria swap en uso
- Tiempo de respuesta > 10 segundos
- Error rate > 10%

**Acción**: Detener prueba, investigar antes de continuar.

---

### 3. **Post-Prueba**

✅ **Análisis Obligatorio**:
1. Revisar reporte HTML completo
2. Exportar métricas a Excel/Google Sheets
3. Comparar con pruebas anteriores (trend analysis)
4. Documentar issues encontrados en Jira/GitHub
5. Reunión de equipo para revisar hallazgos

✅ **Template de Reporte**:
```markdown
# Reporte de Prueba de Rendimiento
**Fecha**: 2025-01-12
**Tipo**: Load Test Backend
**Duración**: 5 minutos
**Usuarios**: 100

## Resultados
- Throughput: 52 req/s ✅
- Error Rate: 0.3% ✅
- P95 Response Time: 890ms ✅

## Issues Encontrados
1. Verificación biométrica lenta (1.8s promedio)
   - **Severidad**: Media
   - **Ticket**: JIRA-1234
   - **Plan de acción**: Implementar procesamiento asíncrono

## Recomendaciones
- Escalar a 2 instancias de backend para manejar picos
- Implementar Redis cache para endpoints de sync
- Optimizar queries de auditoria (agregar índice en timestamp)

## Archivos Adjuntos
- HTML Report: results/load_test_html_report_20250112/
- Raw Data: results/load_test_20250112.jtl
```

---

### 4. **Ciclo de Mejora Continua**

```
┌─────────────────┐
│  1. Baseline    │  ← Primera prueba de rendimiento
│     Test        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. Identificar │  ← Analizar bottlenecks
│     Bottlenecks │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. Optimizar   │  ← Implementar mejoras
│     Código      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. Re-Test     │  ← Validar mejoras
│     (Regression)│
└────────┬────────┘
         │
         └──────────┐
                    ▼
            ¿Cumple objetivos?
                 │
        ┌────────┴────────┐
        │                 │
       SÍ                NO
        │                 │
        ▼                 │
    Producción            │
                          │
                    (Volver al paso 2)
```

---

## 📈 MÉTRICAS DE ÉXITO ESPERADAS

### Para Producción

| Métrica | Valor Objetivo |
|---------|----------------|
| Tiempo de Respuesta P95 (Login) | < 500ms |
| Tiempo de Respuesta P95 (Biometría) | < 2000ms |
| Tiempo de Respuesta P95 (Sync) | < 1000ms |
| Throughput Global | > 100 req/s |
| Error Rate | < 0.5% |
| Uptime (SOAK 2h) | 100% |
| Capacidad Máxima (BREAKPOINT) | > 500 usuarios concurrentes |

---

## 🔗 RECURSOS ADICIONALES

- [Documentación Oficial JMeter](https://jmeter.apache.org/usermanual/index.html)
- [JMeter Best Practices](https://jmeter.apache.org/usermanual/best-practices.html)
- [BlazeMeter University](https://www.blazemeter.com/university)
- [JMeter Plugins](https://jmeter-plugins.org/)

---

## 📝 CHANGELOG

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0.0 | 2025-01-12 | Implementación inicial - Backend Load Test + Stress Test |

---

## 👥 SOPORTE

Para problemas o preguntas:
1. Revisar sección [Troubleshooting](#troubleshooting)
2. Consultar logs en `results/*.log`
3. Contactar al equipo de DevOps

---

**Última actualización**: 2025-01-12  
**Mantenedor**: Equipo BiometricAuth
