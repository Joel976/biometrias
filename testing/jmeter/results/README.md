# README - Directorio de Resultados

Este directorio almacena todos los resultados de las pruebas de JMeter.

## Archivos Generados

### Archivos .jtl
Datos raw en formato CSV de cada ejecución.

### Archivos .log
Logs de ejecución de JMeter.

### Directorios *_html_report_*
Reportes HTML completos con dashboards y gráficos.

## Limpieza

Para liberar espacio, puedes eliminar resultados antiguos:

```powershell
# Windows
Remove-Item -Path ".\results\*" -Recurse -Force -Exclude "README.md"

# Linux/Mac
rm -rf results/*_* results/*.jtl results/*.log
```

## Retención Recomendada

- Mantener últimos 7 días de resultados
- Archivar resultados críticos en repositorio separado
- Exportar métricas clave a hoja de cálculo
