import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/biometric_service.dart';

/// 📊 UTILIDAD PARA EXPORTAR MÉTRICAS BIOMÉTRICAS
/// Genera archivos CSV y JSON para análisis en Python/R/MATLAB
class BiometricMetricsExporter {
  /// 📈 Exportar datos de validación a CSV (para análisis ROC en Python)
  static Future<String> exportToCSV() async {
    final data = BiometricService.exportValidationData();

    if (data.isEmpty) {
      throw Exception('No hay datos de validación para exportar');
    }

    // Crear CSV
    final csv = StringBuffer();

    // Header
    csv.writeln(
      'timestamp,type,confidence,threshold,accepted,energy,duration_ratio,pitch_captured,pitch_template',
    );

    // Rows
    for (final row in data) {
      csv.writeln(
        '${row['timestamp']},${row['type']},${row['confidence']},${row['threshold']},${row['accepted']},${row['energy']},${row['duration_ratio']},${row['pitch_captured']},${row['pitch_template']}',
      );
    }

    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/biometric_validation_data.csv');
    await file.writeAsString(csv.toString());

    print('[MetricsExporter] ✅ CSV exportado: ${file.path}');
    print('[MetricsExporter] 📊 Total registros: ${data.length}');

    return file.path;
  }

  /// 📊 Exportar métricas FAR/FRR/EER a JSON
  static Future<String> exportMetricsToJSON() async {
    final metrics = BiometricService.calculateBiometricMetrics();

    // Crear JSON con formato bonito
    final jsonString = JsonEncoder.withIndent('  ').convert({
      'export_date': DateTime.now().toIso8601String(),
      'metrics': metrics,
      'interpretation': {
        'FAR':
            'False Acceptance Rate - Porcentaje de impostores aceptados (menor es mejor)',
        'FRR':
            'False Rejection Rate - Porcentaje de usuarios legítimos rechazados (menor es mejor)',
        'EER': 'Equal Error Rate - Punto donde FAR = FRR (menor es mejor)',
        'accuracy': 'Porcentaje de decisiones correctas (mayor es mejor)',
      },
      'standards': {
        'ISO_IEC_19795': 'Biometric Performance Testing and Reporting',
        'ISO_IEC_30107': 'Presentation Attack Detection',
      },
    });

    // Guardar archivo
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/biometric_metrics.json');
    await file.writeAsString(jsonString);

    print('[MetricsExporter] ✅ JSON exportado: ${file.path}');

    return file.path;
  }

  /// 🐍 Generar script Python para análisis ROC
  static Future<String> generatePythonROCScript() async {
    final pythonScript =
        '''
#!/usr/bin/env python3
"""
Script de análisis ROC para sistema biométrico
Generado automáticamente por BiometricMetricsExporter
Fecha: ${DateTime.now().toIso8601String()}
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import roc_curve, auc, confusion_matrix
import seaborn as sns

# Cargar datos
df = pd.read_csv('biometric_validation_data.csv')

# Separar por tipo (voice, ear)
df_voice = df[df['type'] == 'voice']
df_ear = df[df['type'] == 'face']  # 'face' es el tipo de oreja en el código

print(f"📊 Dataset cargado:")
print(f"   - Total validaciones: {len(df)}")
print(f"   - Validaciones de voz: {len(df_voice)}")
print(f"   - Validaciones de oreja: {len(df_ear)}")

# Función para calcular métricas a diferentes thresholds
def calculate_metrics_at_thresholds(confidences, labels, thresholds):
    """
    confidences: array de confianzas (0-1)
    labels: array de labels (True=genuino, False=impostor)
    """
    metrics = []
    for t in thresholds:
        predictions = confidences >= t
        
        # True Positives (genuinos aceptados)
        tp = np.sum((labels == True) & (predictions == True))
        # False Positives (impostores aceptados) - esto es FAR
        fp = np.sum((labels == False) & (predictions == True))
        # True Negatives (impostores rechazados)
        tn = np.sum((labels == False) & (predictions == False))
        # False Negatives (genuinos rechazados) - esto es FRR
        fn = np.sum((labels == True) & (predictions == False))
        
        far = fp / (fp + tn) if (fp + tn) > 0 else 0
        frr = fn / (fn + tp) if (fn + tp) > 0 else 0
        accuracy = (tp + tn) / (tp + tn + fp + fn) if (tp + tn + fp + fn) > 0 else 0
        
        metrics.append({
            'threshold': t,
            'FAR': far,
            'FRR': frr,
            'accuracy': accuracy,
            'tp': tp,
            'fp': fp,
            'tn': tn,
            'fn': fn,
        })
    
    return pd.DataFrame(metrics)

# ⚠️ IMPORTANTE: Necesitas etiquetar tus datos
# Por ahora asumimos que 'accepted' == True significa genuino
# Debes tener una columna 'is_genuine' que indique si el usuario es legítimo
# TODO: Agregar esta columna en el código Dart

# Ejemplo de análisis (ajustar según tus datos reales)
thresholds = np.linspace(0.5, 0.95, 50)

# Si tienes la columna 'is_genuine', úsala así:
# df_metrics = calculate_metrics_at_thresholds(
#     df_voice['confidence'].values,
#     df_voice['is_genuine'].values,
#     thresholds
# )

# Graficar curva FAR vs FRR
plt.figure(figsize=(12, 5))

# Subplot 1: FAR vs FRR
plt.subplot(1, 2, 1)
# plt.plot(df_metrics['threshold'], df_metrics['FAR'], label='FAR', marker='o')
# plt.plot(df_metrics['threshold'], df_metrics['FRR'], label='FRR', marker='s')
plt.xlabel('Threshold')
plt.ylabel('Error Rate')
plt.title('FAR vs FRR - Sistema Biométrico de Voz')
plt.legend()
plt.grid(True)

# Subplot 2: ROC Curve
plt.subplot(1, 2, 2)
# fpr, tpr, _ = roc_curve(labels, confidences)
# roc_auc = auc(fpr, tpr)
# plt.plot(fpr, tpr, label=f'ROC (AUC = {roc_auc:.3f})')
plt.plot([0, 1], [0, 1], 'k--', label='Random')
plt.xlabel('False Positive Rate (FAR)')
plt.ylabel('True Positive Rate (1-FRR)')
plt.title('Curva ROC')
plt.legend()
plt.grid(True)

plt.tight_layout()
plt.savefig('biometric_roc_analysis.png', dpi=300)
print("✅ Gráfico guardado: biometric_roc_analysis.png")

# Matriz de confusión
# cm = confusion_matrix(labels, predictions)
# plt.figure(figsize=(8, 6))
# sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
# plt.xlabel('Predicción')
# plt.ylabel('Real')
# plt.title('Matriz de Confusión')
# plt.savefig('confusion_matrix.png', dpi=300)

print("")
print("📊 PRÓXIMOS PASOS PARA COMPLETAR ANÁLISIS:")
print("1. Agregar columna 'is_genuine' a los datos de validación")
print("2. Ejecutar pruebas con usuarios impostores (cross-validation)")
print("3. Descomentar código de gráficos arriba")
print("4. Calcular EER (punto donde FAR = FRR)")
print("")
print("🎓 PARA TESIS:")
print("- Incluir gráfico ROC en Capítulo 4 (Resultados)")
print("- Reportar FAR, FRR, EER con intervalos de confianza")
print("- Comparar con papers del estado del arte")
''';

    // Guardar script
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/analyze_biometric_roc.py');
    await file.writeAsString(pythonScript);

    print('[MetricsExporter] ✅ Script Python generado: ${file.path}');
    print('[MetricsExporter] 🐍 Ejecutar con: python3 ${file.path}');

    return file.path;
  }

  /// 📋 Generar reporte completo para tesis
  static Future<Map<String, String>> generateThesisReport() async {
    final csvPath = await exportToCSV();
    final jsonPath = await exportMetricsToJSON();
    final pythonPath = await generatePythonROCScript();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('📊 REPORTE PARA TESIS GENERADO');
    print('═══════════════════════════════════════════════════════');
    print('✅ Datos CSV: $csvPath');
    print('✅ Métricas JSON: $jsonPath');
    print('✅ Script Python: $pythonPath');
    print('');
    print('📖 CÓMO USAR EN TU TESIS:');
    print('1. Copiar archivos CSV y JSON a tu computadora');
    print('2. Ejecutar script Python para generar gráficos ROC');
    print('3. Incluir gráficos en Capítulo 4 (Resultados)');
    print('4. Reportar métricas FAR/FRR/EER en tablas');
    print('═══════════════════════════════════════════════════════');
    print('');

    return {'csv': csvPath, 'json': jsonPath, 'python': pythonPath};
  }
}
