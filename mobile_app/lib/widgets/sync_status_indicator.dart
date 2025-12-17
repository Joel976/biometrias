import 'package:flutter/material.dart';
import 'dart:async';
import '../services/bidirectional_sync_service.dart';

/// Widget reactivo que muestra el estado de sincronización en tiempo real
class SyncStatusIndicator extends StatefulWidget {
  final BidirectionalSyncService syncService;

  const SyncStatusIndicator({Key? key, required this.syncService})
    : super(key: key);

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _syncStatusSubscription;

  bool _hasInternet = false;
  bool _isSyncing = false;
  bool _isChecking = false;
  int _attempts = 0;
  String _lastStatus = 'Inicializando...';

  @override
  void initState() {
    super.initState();
    _hasInternet = widget.syncService.hasInternet;
    _attempts = widget.syncService.syncAttempts;
    _listenToStreams();
  }

  void _listenToStreams() {
    // Escuchar cambios de conectividad
    _connectivitySubscription = widget.syncService.connectivityStream.listen((
      hasInternet,
    ) {
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
          _lastStatus = hasInternet
              ? 'Conectado a internet'
              : 'Sin conexión a internet';
        });
      }
    });

    // Escuchar estado de sincronización
    _syncStatusSubscription = widget.syncService.syncStatusStream.listen((
      status,
    ) {
      if (mounted) {
        setState(() {
          _isChecking = status['checking'] == true;
          _isSyncing = status['syncing'] == true;
          _hasInternet = status['hasInternet'] ?? _hasInternet;
          _attempts = status['attempts'] ?? _attempts;

          if (status['skipped'] == true) {
            _lastStatus = 'Sin internet - Esperando conexión';
          } else if (status['syncing'] == true) {
            _lastStatus = 'Sincronizando...';
          } else if (status['completed'] == true) {
            final uploaded = status['uploaded'] ?? 0;
            final downloaded = status['downloaded'] ?? 0;
            _lastStatus = 'Sincronizado ✓ (↑$uploaded ↓$downloaded)';
          } else if (status['checking'] == true) {
            _lastStatus = 'Verificando conectividad...';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getBorderColor(), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono de estado
          _buildStatusIcon(),
          const SizedBox(width: 8),
          // Texto de estado
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _hasInternet ? 'Online' : 'Offline',
                style: TextStyle(
                  color: _getTextColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (_attempts > 0)
                Text(
                  'Verificaciones: $_attempts',
                  style: TextStyle(
                    color: _getTextColor().withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    if (_isSyncing) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
        ),
      );
    }

    if (_isChecking) {
      return Icon(Icons.search, size: 16, color: _getTextColor());
    }

    return Icon(
      _hasInternet ? Icons.wifi : Icons.wifi_off,
      size: 16,
      color: _getTextColor(),
    );
  }

  Color _getBackgroundColor() {
    if (_isSyncing) return Colors.blue.withOpacity(0.1);
    if (_hasInternet) return Colors.green.withOpacity(0.1);
    return Colors.red.withOpacity(0.1);
  }

  Color _getBorderColor() {
    if (_isSyncing) return Colors.blue;
    if (_hasInternet) return Colors.green;
    return Colors.red;
  }

  Color _getTextColor() {
    if (_isSyncing) return Colors.blue;
    if (_hasInternet) return Colors.green;
    return Colors.red;
  }
}

/// Widget expandido con más información
class SyncStatusCard extends StatefulWidget {
  final BidirectionalSyncService syncService;

  const SyncStatusCard({Key? key, required this.syncService}) : super(key: key);

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<Map<String, dynamic>>? _syncStatusSubscription;

  bool _hasInternet = false;
  bool _isSyncing = false;
  int _attempts = 0;
  String _lastStatus = 'Esperando...';
  int _lastUploaded = 0;
  int _lastDownloaded = 0;

  @override
  void initState() {
    super.initState();
    _hasInternet = widget.syncService.hasInternet;
    _attempts = widget.syncService.syncAttempts;
    _listenToStreams();
  }

  void _listenToStreams() {
    _connectivitySubscription = widget.syncService.connectivityStream.listen((
      hasInternet,
    ) {
      if (mounted) {
        setState(() {
          _hasInternet = hasInternet;
        });
      }
    });

    _syncStatusSubscription = widget.syncService.syncStatusStream.listen((
      status,
    ) {
      if (mounted) {
        setState(() {
          _isSyncing = status['syncing'] == true;
          _hasInternet = status['hasInternet'] ?? _hasInternet;
          _attempts = status['attempts'] ?? _attempts;

          if (status['skipped'] == true) {
            _lastStatus = 'Sin conexión - Sincronización omitida';
          } else if (status['syncing'] == true) {
            _lastStatus = 'Sincronizando con el servidor...';
          } else if (status['completed'] == true) {
            _lastUploaded = status['uploaded'] ?? 0;
            _lastDownloaded = status['downloaded'] ?? 0;
            _lastStatus = 'Última sincronización exitosa';
          } else if (status['checking'] == true) {
            _lastStatus = 'Verificando conectividad...';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Estado principal
            Row(
              children: [
                Icon(
                  _hasInternet ? Icons.cloud_done : Icons.cloud_off,
                  size: 48,
                  color: _hasInternet ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasInternet ? 'Conectado' : 'Sin conexión',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _lastStatus,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                if (_isSyncing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),

            const Divider(height: 24),

            // Estadísticas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Verificaciones',
                  _attempts.toString(),
                  Icons.search,
                ),
                _buildStatColumn(
                  'Subidos',
                  _lastUploaded.toString(),
                  Icons.upload,
                ),
                _buildStatColumn(
                  'Descargados',
                  _lastDownloaded.toString(),
                  Icons.download,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Información adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasInternet
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasInternet ? Icons.info_outline : Icons.warning_amber,
                    size: 20,
                    color: _hasInternet ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _hasInternet
                          ? 'Los datos se guardan localmente y en el servidor'
                          : 'Los datos se guardan localmente. Se sincronizarán cuando haya internet.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasInternet
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
