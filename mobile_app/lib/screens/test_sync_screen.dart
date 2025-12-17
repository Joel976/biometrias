import 'package:flutter/material.dart';
import '../services/bidirectional_sync_service.dart';

/// Pantalla de prueba para ver la sincronización en tiempo real
/// Verifica cada 5 segundos si hay internet
class TestSyncScreen extends StatefulWidget {
  const TestSyncScreen({Key? key}) : super(key: key);

  @override
  State<TestSyncScreen> createState() => _TestSyncScreenState();
}

class _TestSyncScreenState extends State<TestSyncScreen> {
  final _syncService = BidirectionalSyncService();

  // Estados para la UI
  bool _hasInternet = false;
  bool _isSyncing = false;
  int _attempts = 0;
  String _lastStatus = 'Esperando...';
  int _uploaded = 0;
  int _downloaded = 0;

  @override
  void initState() {
    super.initState();

    // Estado inicial
    _hasInternet = _syncService.hasInternet;

    // Iniciar monitoreo cada 5 segundos
    _syncService.startAutoSync(
      idUsuario: 123, // ID de prueba
      dispositivoId: 'test_device',
      interval: Duration(seconds: 5), // 5 segundos para testing
    );

    // Escuchar cambios de conectividad
    _syncService.connectivityStream.listen((hasInternet) {
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
          _lastStatus = hasInternet ? '✅ Conexión detectada' : '❌ Sin conexión';
        });
      }
    });

    // Escuchar estado de sincronización
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          if (status['checking'] == true) {
            _attempts = status['attempts'] ?? _attempts;
            _lastStatus = 'Verificando conectividad...';
          }

          if (status['skipped'] == true) {
            _lastStatus = '⏭️ Sin internet - Sincronización omitida';
          }

          if (status['syncing'] == true) {
            _isSyncing = true;
            _lastStatus = '🔄 Sincronizando con el servidor...';
          }

          if (status['completed'] == true) {
            _isSyncing = false;
            _uploaded = status['uploaded'] ?? 0;
            _downloaded = status['downloaded'] ?? 0;
            _lastStatus = '✅ Sincronizado (↑$_uploaded ↓$_downloaded)';
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Sincronización (5 segundos)'),
        backgroundColor: _hasInternet ? Colors.green : Colors.red,
        actions: [
          // Indicador compacto
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _hasInternet ? Icons.wifi : Icons.wifi_off,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                if (_isSyncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono principal
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _hasInternet
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _hasInternet ? Colors.green : Colors.red,
                    width: 3,
                  ),
                ),
                child: Icon(
                  _hasInternet ? Icons.cloud_done : Icons.cloud_off,
                  size: 80,
                  color: _hasInternet ? Colors.green : Colors.red,
                ),
              ),

              SizedBox(height: 32),

              // Estado principal
              Text(
                _hasInternet ? 'CONECTADO' : 'DESCONECTADO',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _hasInternet ? Colors.green : Colors.red,
                ),
              ),

              SizedBox(height: 16),

              // Estado detallado
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _lastStatus,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 32),

              // Estadísticas
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'ESTADÍSTICAS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Divider(height: 24),
                      _buildStatRow(
                        'Verificaciones',
                        _attempts.toString(),
                        Icons.search,
                      ),
                      SizedBox(height: 12),
                      _buildStatRow(
                        'Subidos',
                        _uploaded.toString(),
                        Icons.upload,
                      ),
                      SizedBox(height: 12),
                      _buildStatRow(
                        'Descargados',
                        _downloaded.toString(),
                        Icons.download,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 32),

              // Indicador de sincronización
              if (_isSyncing)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Sincronizando...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

              SizedBox(height: 32),

              // Instrucciones
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'PRUEBA ESTO:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('1. Observa el contador de verificaciones'),
                    Text('2. Activa modo avión → Ve cómo cambia a ROJO'),
                    Text('3. Desactiva modo avión → Ve cómo cambia a VERDE'),
                    Text('4. Verifica cada 5 segundos automáticamente'),
                    SizedBox(height: 8),
                    Text(
                      'Los logs aparecen en la consola de Flutter',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: Colors.blue),
            SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 16)),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
