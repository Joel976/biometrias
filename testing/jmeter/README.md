# GUÍA RÁPIDA - JMeter BiometricAuth

## 🚀 Inicio Rápido (5 minutos)

### Windows
```powershell
cd C:\Users\User\Downloads\biometrias\testing\jmeter
.\quick_start.bat
```

### Linux/Mac
```bash
cd /path/to/biometrias/testing/jmeter
chmod +x quick_start.sh
./quick_start.sh
```

---

## 📋 Archivos Principales

| Archivo | Descripción |
|---------|-------------|
| `BiometricAuth_Backend_Load_Test.jmx` | Prueba de carga (100 usuarios, 5 min) |
| `BiometricAuth_Stress_Test.jmx` | Pruebas de estrés (SPIKE/SOAK/BREAKPOINT) |
| `run_all_tests.bat/.sh` | Suite completa con menú interactivo |
| `quick_start.bat/.sh` | Inicio rápido para principiantes |
| `JMETER_IMPLEMENTACION.md` | Documentación completa (LEER PRIMERO) |

---

## ⚡ Comandos Esenciales

### Modo GUI (Desarrollo)
```bash
jmeter -t BiometricAuth_Backend_Load_Test.jmx
```

### Modo NO-GUI (Producción)
```bash
jmeter -n -t BiometricAuth_Backend_Load_Test.jmx \
       -l results/test.jtl \
       -e -o results/test_report
```

### Ver Reporte Existente
```bash
# Generar HTML desde archivo .jtl
jmeter -g results/test.jtl -o results/new_report
```

---

## 📊 Estructura de Resultados

```
results/
├── load_test_20250112_143022.jtl          # Datos raw
├── load_test_20250112_143022.log          # Log de ejecución
└── load_test_report_20250112_143022/      # Reporte HTML
    ├── index.html                          # Dashboard principal
    └── content/
        ├── pages/
        │   ├── OverTime.html              # Gráficos temporales
        │   └── ResponseTimesPercentiles.html
        └── js/
```

---

## 🎯 Métricas Objetivo

| Endpoint | P95 Response Time | Error Rate |
|----------|-------------------|------------|
| `/api/auth/register` | < 500ms | < 1% |
| `/api/auth/login` | < 400ms | < 1% |
| `/api/biometria/verificar-oreja` | < 2000ms | < 2% |
| `/api/sync/descarga` | < 800ms | < 1% |
| `/api/sync/subida` | < 1000ms | < 1% |

---

## 🔍 Checklist Pre-Prueba

- [ ] Backend corriendo en `http://192.168.100.197:3000`
- [ ] Base de datos PostgreSQL activa
- [ ] JMeter instalado (`jmeter -v`)
- [ ] Espacio en disco > 2 GB
- [ ] Backup de BD realizado
- [ ] Equipo notificado (ventana de pruebas)

---

## 🐛 Solución Rápida de Problemas

### Backend no responde
```bash
curl http://192.168.100.197:3000/api/health
# Si falla → Iniciar backend:
cd backend && npm start
```

### JMeter sin memoria
```bash
# Incrementar heap en jmeter.bat o jmeter
set HEAP=-Xms1g -Xmx4g
```

### Resultados no se generan
```bash
# Generar manualmente
jmeter -g results/test.jtl -o results/manual_report
```

---

## 📚 Recursos

- **Documentación Completa**: `JMETER_IMPLEMENTACION.md`
- **JMeter Docs**: https://jmeter.apache.org/usermanual/
- **Soporte**: Contactar equipo DevOps

---

**Última actualización**: 2025-01-12  
**Versión**: 1.0.0
