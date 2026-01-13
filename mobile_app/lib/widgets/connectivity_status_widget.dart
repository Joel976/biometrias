import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../services/sync_manager.dart';
import '../services/admin_settings_service.dart';
import '../models/admin_settings.dart';

/// Widget que muestra el estado de conectividad de la app
/// con iconografía clara y animaciones
class ConnectivityStatusWidget extends StatefulWidget {
  final Widget child;
  final SyncManager? syncManager;

  const ConnectivityStatusWidget({
    Key? key,
    required this.child,
    this.syncManager,
  }) : super(key: key);

  @override
  State<ConnectivityStatusWidget> createState() =>
      _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget>
    with WidgetsBindingObserver {
  final _connectivity = Connectivity();
  final _adminService = AdminSettingsService();
  bool _isOnline = true;
  bool _showSyncBanner = false;
  late SyncManager _syncManager;
  Timer? _connectivityCheckTimer;
  Timer? _settingsCheckTimer;
  int _checkCount = 0; // Contador de verificaciones
  bool _isChecking = false; // Para animar el cambio de color
  AdminSettings? _settings;
  DateTime? _lastOfflineBannerTime; // Control de banner offline

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncManager = widget.syncManager ?? SyncManager();

    _loadSettings();
    _checkConnectivity();

    // Verificar conectividad cada 60 segundos (1 minuto)
    _connectivityCheckTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      _checkCount++;
      debugPrint('[Connectivity] 🔍 Verificación #$_checkCount...');

      // Animar cambio de color
      if (mounted) {
        setState(() {
          _isChecking = true;
        });
      }

      _checkConnectivity();

      // Volver al color original después de 2 segundos
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isChecking = false;
          });
        }
      });
    });

    _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        // result es una lista; si está vacía, no hay conexión
        final wasOffline = !_isOnline;
        _isOnline =
            result.isNotEmpty && result.first != ConnectivityResult.none;

        print(
          '🌐🌐🌐 [ConnectivityWidget] CAMBIO DE CONEXIÓN DETECTADO 🌐🌐🌐',
        );
        print('🌐 Estado anterior: ${wasOffline ? "OFFLINE" : "ONLINE"}');
        print('🌐 Estado nuevo: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        print('🌐 Resultado: $result');

        if (_isOnline && wasOffline) {
          print(
            '🌐✅ ¡RECONEXIÓN DETECTADA! Iniciando sincronización automática...',
          );

          // Mostrar banner cuando se reconecta
          _showSyncBanner = true;
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) setState(() => _showSyncBanner = false);
          });

          // Trigger sync automático
          print('🌐🔄 Llamando a performSync() automáticamente...');
          _syncManager
              .performSync()
              .then((_) {
                print('🌐✅ Sincronización automática completada');
              })
              .catchError((error) {
                print('🌐❌ Error en sincronización automática: $error');
              });
        } else if (!_isOnline) {
          print('🌐❌ Conexión perdida - modo offline');
        }
      });
    });

    // Escuchar estado de sincronización
    _syncManager.syncStatus.listen((status) {
      if (mounted) {
        setState(() {}); // Rebuild para mostrar cambios de sync
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _adminService.loadSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
        });
      }
    } catch (e) {
      debugPrint('[Connectivity] Error cargando settings: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityCheckTimer?.cancel();
    _settingsCheckTimer?.cancel();
    super.dispose();
  }

  /// Detecta cuando la app vuelve del background o se desbloquea
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    debugPrint('[Connectivity] 📱 Lifecycle cambió a: $state');

    if (state == AppLifecycleState.resumed) {
      // La app volvió al foreground (desbloqueo o volver de otra app)
      debugPrint('[Connectivity] ✅ App resumida - verificando conectividad...');
      _checkConnectivity();

      // También recargar settings por si cambiaron
      _loadSettings();
    } else if (state == AppLifecycleState.paused) {
      // La app fue a background
      debugPrint('[Connectivity] ⏸️ App pausada');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      // Verificar conectividad con timeout
      final result = await _connectivity.checkConnectivity().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
            '[Connectivity] ⚠️ Timeout en verificación de conectividad',
          );
          return [ConnectivityResult.none];
        },
      );

      final wasOnline = _isOnline;
      final isOnline =
          result.isNotEmpty && result.first != ConnectivityResult.none;

      // Si detectamos cambio de offline a online, hacer doble verificación
      if (!wasOnline && isOnline) {
        debugPrint(
          '[Connectivity] 🔄 Detectado cambio a ONLINE, verificando de nuevo...',
        );
        await Future.delayed(Duration(seconds: 1));
        final recheck = await _connectivity.checkConnectivity();
        final recheckOnline =
            recheck.isNotEmpty && recheck.first != ConnectivityResult.none;

        if (recheckOnline != isOnline) {
          debugPrint(
            '[Connectivity] ⚠️ Estado inconsistente, usando rechecked: $recheckOnline',
          );
        }
      }

      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
      }

      // Log del estado
      if (wasOnline != isOnline) {
        debugPrint(
          '[Connectivity] 📡 Estado cambió: ${isOnline ? '✅ ONLINE' : '❌ OFFLINE'}',
        );

        // Mostrar banner de cambio de estado
        if (isOnline) {
          setState(() {
            _showSyncBanner = true;
          });
          Future.delayed(Duration(seconds: 3), () {
            if (mounted) setState(() => _showSyncBanner = false);
          });
        }
      } else {
        debugPrint(
          '[Connectivity] 📡 Estado: ${isOnline ? '✅ ONLINE' : '❌ OFFLINE'}',
        );
      }
    } catch (e) {
      debugPrint('[Connectivity] ⚠️ Error verificando conectividad: $e');
      // En caso de error, asumir offline por seguridad
      if (mounted) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay settings cargados, usar valores por defecto
    final showNetworkIndicator = _settings?.showNetworkIndicator ?? true;
    final showSyncStatus = _settings?.showSyncStatus ?? true;

    return Stack(
      children: [
        widget.child,
        // Indicador de conectividad (solo si está habilitado)
        if (showNetworkIndicator)
          Positioned(
            bottom: 16, // Cambiado de top a bottom
            right: 16,
            child: _buildConnectivityBadge(),
          ),
        // Banner de reconexión/sincronización (solo si está habilitado)
        if (showSyncStatus && (_showSyncBanner || !_isOnline))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildConnectivityBanner(),
          ),
      ],
    );
  }

  /// Badge flotante con ícono de conectividad
  Widget _buildConnectivityBadge() {
    // Badge más proporcionado y elegante
    return Container(
      padding: const EdgeInsets.all(8),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isOnline ? Colors.green : Colors.red,
        boxShadow: [
          BoxShadow(
            color: (_isOnline ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _isOnline ? Icons.wifi : Icons.wifi_off,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// Banner que muestra estado de conectividad/sincronización
  Widget _buildConnectivityBanner() {
    if (_showSyncBanner && _isOnline) {
      return _buildSyncBanner();
    }

    // Solo mostrar banner offline según intervalo configurado
    if (!_isOnline && _shouldShowOfflineBanner()) {
      return _buildOfflineBanner();
    }

    return const SizedBox.shrink();
  }

  /// Verificar si debe mostrarse el banner offline según intervalo
  bool _shouldShowOfflineBanner() {
    final intervalMinutes = _settings?.offlineMessageIntervalMinutes ?? 1;
    final now = DateTime.now();

    if (_lastOfflineBannerTime == null) {
      _lastOfflineBannerTime = now;
      return true; // Primera vez, mostrar
    }

    final difference = now.difference(_lastOfflineBannerTime!);
    if (difference.inMinutes >= intervalMinutes) {
      _lastOfflineBannerTime = now;
      return true; // Ya pasó el intervalo, mostrar
    }

    return false; // Aún no pasa el intervalo, no mostrar
  }

  /// Banner cuando está sincronizando
  Widget _buildSyncBanner() {
    return Container(
      color: Colors.blue.shade600,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                '✓ Conectado • Sincronizando datos...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner cuando está sin internet
  Widget _buildOfflineBanner() {
    // Cambiar color cuando está verificando - amarillo brillante muy notorio
    final backgroundColor = _isChecking
        ? Colors
              .yellow
              .shade600 // Amarillo brillante durante verificación (2 segundos)
        : Colors.orange.shade700; // Color naranja normal

    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '✗ Sin conexión a internet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Los datos se guardarán localmente • Verificando... ($_checkCount)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
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
}

/// Modelo para estados de sincronización
enum SyncStatus {
  idle,
  syncing,
  syncComplete,
  syncError,
  offline,
  serverUnavailable,
}
