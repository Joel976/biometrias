import 'package:flutter/material.dart';
import '../services/sync_manager.dart';

/// Widget que muestra el contador de datos pendientes de sincronizar
class PendingSyncBadge extends StatefulWidget {
  final SyncManager syncManager;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const PendingSyncBadge({
    Key? key,
    required this.syncManager,
    this.badgeColor,
    this.badgeTextColor,
  }) : super(key: key);

  @override
  State<PendingSyncBadge> createState() => _PendingSyncBadgeState();
}

class _PendingSyncBadgeState extends State<PendingSyncBadge> {
  late Stream<int> _pendingCountStream;

  @override
  void initState() {
    super.initState();
    _pendingCountStream = widget.syncManager.getPendingSyncCountStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _pendingCountStream,
      builder: (context, snapshot) {
        final pendingCount = snapshot.data ?? 0;

        if (pendingCount == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.badgeColor ?? Colors.orange,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_upload,
                color: widget.badgeTextColor ?? Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '$pendingCount pendiente${pendingCount > 1 ? 's' : ''}',
                style: TextStyle(
                  color: widget.badgeTextColor ?? Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de estado de sincronización
class SyncStatusCard extends StatefulWidget {
  final SyncManager syncManager;
  final VoidCallback? onSyncPressed;

  const SyncStatusCard({
    Key? key,
    required this.syncManager,
    this.onSyncPressed,
  }) : super(key: key);

  @override
  State<SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<SyncStatusCard> {
  bool _isSyncing = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.blue, size: 30),
                const SizedBox(width: 14),
                const Text(
                  'Estado de Sincronización',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: widget.syncManager.getPendingSyncCountStream(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.data ?? 0;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          pendingCount == 0
                              ? '✓ Todo sincronizado'
                              : '$pendingCount dato${pendingCount != 1 ? 's' : ''} pendiente${pendingCount != 1 ? 's' : ''}',
                          style: TextStyle(
                            color: pendingCount == 0
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isSyncing)
                          SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncNow,
                          icon: const Icon(Icons.cloud_upload, size: 20),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Sincronizar Ahora'),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);

    try {
      final result = await widget.syncManager.syncOfflineData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
      widget.onSyncPressed?.call();
    }
  }
}
