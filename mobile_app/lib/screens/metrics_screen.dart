import 'package:flutter/material.dart';
import '../services/biometric_service.dart';
import '../utils/biometric_metrics_exporter.dart';

/// 📊 PANTALLA DE MÉTRICAS BIOMÉTRICAS
/// Para visualizar FAR/FRR/EER y exportar datos para tesis
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({Key? key}) : super(key: key);

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = false;
  String? _exportMessage;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  void _loadMetrics() {
    setState(() {
      _metrics = BiometricService.calculateBiometricMetrics();
    });
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
      _exportMessage = null;
    });

    try {
      final paths = await BiometricMetricsExporter.generateThesisReport();

      setState(() {
        _isLoading = false;
        _exportMessage =
            'Archivos exportados:\n'
            '✅ CSV: ${paths['csv']}\n'
            '✅ JSON: ${paths['json']}\n'
            '✅ Python: ${paths['python']}';
      });

      // Mostrar diálogo
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Exportación Exitosa'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Archivos generados para tu tesis:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildFileInfo('📊 Datos CSV', paths['csv']!),
                  _buildFileInfo('📈 Métricas JSON', paths['json']!),
                  _buildFileInfo('🐍 Script Python', paths['python']!),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '💡 Próximos pasos:\n'
                      '1. Copia los archivos a tu PC\n'
                      '2. Ejecuta el script Python\n'
                      '3. Incluye gráficos en tu tesis',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _exportMessage = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFileInfo(String label, String path) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  path,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Métricas Biométricas'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
            tooltip: 'Actualizar métricas',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  const Text(
                    'Métricas de Rendimiento',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Según norma ISO/IEC 19795 - Biometric Performance Testing',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // Métricas principales
                  if (_metrics != null && !_metrics!.containsKey('error')) ...[
                    _buildMetricCard(
                      '📉 FAR (False Acceptance Rate)',
                      (_metrics!['FAR'] * 100).toStringAsFixed(2) + '%',
                      'Porcentaje de impostores aceptados',
                      _getColorForFAR(_metrics!['FAR']),
                      '⬇️ Menor es mejor (ideal: <2%)',
                    ),
                    _buildMetricCard(
                      '📉 FRR (False Rejection Rate)',
                      (_metrics!['FRR'] * 100).toStringAsFixed(2) + '%',
                      'Porcentaje de usuarios legítimos rechazados',
                      _getColorForFRR(_metrics!['FRR']),
                      '⬇️ Menor es mejor (ideal: <5%)',
                    ),
                    _buildMetricCard(
                      '🎯 EER (Equal Error Rate)',
                      (_metrics!['EER'] * 100).toStringAsFixed(2) + '%',
                      'Punto donde FAR = FRR',
                      _getColorForEER(_metrics!['EER']),
                      '⬇️ Menor es mejor (ideal: <3%)',
                    ),
                    _buildMetricCard(
                      '✅ Accuracy',
                      (_metrics!['accuracy'] * 100).toStringAsFixed(2) + '%',
                      'Porcentaje de decisiones correctas',
                      _getColorForAccuracy(_metrics!['accuracy']),
                      '⬆️ Mayor es mejor (ideal: >95%)',
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Detalles estadísticos
                    const Text(
                      'Estadísticas Detalladas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildStatRow(
                      'Total validaciones',
                      '${_metrics!['total_validations']}',
                    ),
                    _buildStatRow(
                      'Intentos de usuarios legítimos',
                      '${_metrics!['genuine_attempts']}',
                    ),
                    _buildStatRow(
                      '  ✅ Aceptados correctamente',
                      '${_metrics!['genuine_accepted']}',
                    ),
                    _buildStatRow(
                      '  ❌ Rechazados (FRR)',
                      '${_metrics!['genuine_rejected']}',
                    ),
                    const SizedBox(height: 8),
                    _buildStatRow(
                      'Intentos de impostores',
                      '${_metrics!['impostor_attempts']}',
                    ),
                    _buildStatRow(
                      '  ✅ Rechazados correctamente',
                      '${_metrics!['impostor_rejected']}',
                    ),
                    _buildStatRow(
                      '  ⚠️ Aceptados (FAR)',
                      '${_metrics!['impostor_accepted']}',
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // Thresholds
                    const Text(
                      'Configuración de Umbrales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildStatRow(
                      'Threshold Voz',
                      '${(_metrics!['threshold_voice'] * 100).toStringAsFixed(0)}%',
                    ),
                    _buildStatRow(
                      'Threshold Oreja',
                      '${(_metrics!['threshold_face'] * 100).toStringAsFixed(0)}%',
                    ),
                  ] else ...[
                    // Sin datos
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay datos suficientes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Realiza al menos 10 intentos de autenticación para generar métricas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Botón de exportación
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _exportData,
                      icon: const Icon(Icons.download),
                      label: const Text(
                        'Exportar Datos para Tesis',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  if (_exportMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        _exportMessage!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Información adicional
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '📚 Para tu Tesis',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Incluir estas métricas en Capítulo 4 (Resultados)\n'
                          '• Generar curva ROC con script Python\n'
                          '• Comparar con estado del arte (papers 2022-2024)\n'
                          '• Reportar intervalos de confianza al 95%',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String description,
    Color color,
    String tip,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(tip, style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _getColorForFAR(double far) {
    if (far < 0.02) return Colors.green;
    if (far < 0.05) return Colors.orange;
    return Colors.red;
  }

  Color _getColorForFRR(double frr) {
    if (frr < 0.05) return Colors.green;
    if (frr < 0.10) return Colors.orange;
    return Colors.red;
  }

  Color _getColorForEER(double eer) {
    if (eer < 0.03) return Colors.green;
    if (eer < 0.05) return Colors.orange;
    return Colors.red;
  }

  Color _getColorForAccuracy(double accuracy) {
    if (accuracy > 0.95) return Colors.green;
    if (accuracy > 0.90) return Colors.orange;
    return Colors.red;
  }
}
