import 'package:flutter/material.dart';
import '../services/bidirectional_sync_service.dart';
import '../widgets/sync_status_indicator.dart';

/// Ejemplo de pantalla principal con sincronización reactiva
class HomeScreenExample extends StatefulWidget {
  final int userId;
  final String deviceId;

  const HomeScreenExample({
    Key? key,
    required this.userId,
    required this.deviceId,
  }) : super(key: key);

  @override
  State<HomeScreenExample> createState() => _HomeScreenExampleState();
}

class _HomeScreenExampleState extends State<HomeScreenExample> {
  late final BidirectionalSyncService _syncService;

  @override
  void initState() {
    super.initState();

    // Inicializar servicio de sincronización
    _syncService = BidirectionalSyncService();

    // Iniciar monitoreo cada 5 minutos
    _syncService.startAutoSync(
      idUsuario: widget.userId,
      dispositivoId: widget.deviceId,
      interval: const Duration(minutes: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi App Biométrica'),
        actions: [
          // Indicador compacto en AppBar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SyncStatusIndicator(syncService: _syncService),
          ),
        ],
      ),
      body: Column(
        children: [
          // Card expandido con información completa
          SyncStatusCard(syncService: _syncService),

          // Tu contenido aquí
          Expanded(child: Center(child: Text('Contenido de tu app'))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}

/// Ejemplo MÍNIMO para el AppBar solamente
class MinimalExample extends StatefulWidget {
  @override
  State<MinimalExample> createState() => _MinimalExampleState();
}

class _MinimalExampleState extends State<MinimalExample> {
  final _syncService = BidirectionalSyncService();

  @override
  void initState() {
    super.initState();
    _syncService.startAutoSync(
      idUsuario: 123, // Tu ID de usuario
      dispositivoId: 'device123',
      interval: const Duration(minutes: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi App'),
        actions: [
          // Solo el indicador compacto
          SyncStatusIndicator(syncService: _syncService),
          const SizedBox(width: 8),
        ],
      ),
      body: const Center(child: Text('Tu contenido aquí')),
    );
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
