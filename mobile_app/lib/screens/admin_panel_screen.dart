import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/admin_settings_service.dart';
import '../services/biometric_backend_service.dart';
import '../services/local_database_service.dart';
import '../models/admin_settings.dart';
import '../models/user.dart';
import '../config/api_config.dart';

/// Pantalla del Panel de Administración
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _adminService = AdminSettingsService();
  final _backendService = BiometricBackendService();
  final _dbService = LocalDatabaseService();

  AdminSettings? _settings;
  bool _isLoading = true;

  // 🆕 Usuarios por categoría de sincronización
  List<User> _offlineOnlyUsers = [];
  List<User> _onlineOnlyUsers = [];
  List<User> _syncedUsers = [];
  bool _isLoadingOfflineUsers = false;
  bool _isLoadingOnlineUsers = false;
  bool _isLoadingSyncedUsers = false;

  // Gestión de Frases Dinámicas
  List<Map<String, dynamic>> _frases = [];
  bool _isLoadingFrases = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _adminService.loadSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error cargando configuraciones: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;

    try {
      debugPrint('[AdminPanel] 💾 Guardando configuraciones...');
      debugPrint('[AdminPanel]    URL a guardar: ${_settings!.apiBaseUrl}');

      await _adminService.saveSettings(_settings!);
      debugPrint('[AdminPanel] ✅ Configuraciones guardadas en storage');

      // ⚡ IMPORTANTE: Recargar configuración de la API
      debugPrint('[AdminPanel] 🔄 Recargando ApiConfig...');
      final apiConfig = ApiConfig();
      await apiConfig.reloadSettings();

      debugPrint(
        '[AdminPanel] ✅ ApiConfig recargado con URL: ${_settings!.apiBaseUrl}',
      );

      _showSuccess('Configuraciones guardadas exitosamente');
    } catch (e) {
      debugPrint('[AdminPanel] ❌ Error: $e');
      _showError('Error guardando configuraciones: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Confirmar Restauración'),
        content: Text(
          '¿Estás seguro de que deseas restaurar todas las configuraciones a sus valores por defecto?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _adminService.resetToDefaults();
      await _loadSettings();
      _showSuccess('Configuraciones restauradas a valores por defecto');
    }
  }

  // 🆕 Cargar usuarios SOLO OFFLINE (registrados localmente pero no en backend)
  Future<void> _loadOfflineOnlyUsers() async {
    setState(() => _isLoadingOfflineUsers = true);
    try {
      print('[AdminPanel] 📱 Buscando usuarios solo offline...');

      // Obtener todos los usuarios locales
      final localUsers = await _dbService.getAllUsers();

      // Verificar conectividad de red (sin intentar conectarse al backend)
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      final hasNetworkConnection =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      if (!hasNetworkConnection) {
        // Sin conexión de red - todos los usuarios locales son "offline only"
        print(
          '[AdminPanel] ⚠️ Sin conexión de red. Mostrando todos los usuarios locales como offline.',
        );
        setState(() {
          _offlineOnlyUsers = localUsers;
          _isLoadingOfflineUsers = false;
        });
        _showError(
          'Sin conexión. Mostrando ${localUsers.length} usuarios locales',
        );
        return;
      }

      // Con conexión - comparar con backend para encontrar usuarios SOLO offline
      print('[AdminPanel] 🌐 Conexión detectada. Comparando con backend...');

      // Obtener usuarios del backend
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://167.71.155.9:3001',
          connectTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      final response = await dio.get('/usuarios');
      final backendUsers = <String>{};

      if (response.statusCode == 200 && response.data is List) {
        for (var userData in response.data as List) {
          final user = User.fromJson(userData as Map<String, dynamic>);
          backendUsers.add(user.identificadorUnico);
        }
      }

      // Filtrar usuarios que SOLO están offline (no en backend)
      final offlineOnly = localUsers.where((user) {
        return !backendUsers.contains(user.identificadorUnico);
      }).toList();

      setState(() {
        _offlineOnlyUsers = offlineOnly;
        _isLoadingOfflineUsers = false;
      });

      print(
        '[AdminPanel] 📱 ${offlineOnly.length} usuarios solo offline encontrados',
      );
      _showSuccess('${offlineOnly.length} usuarios solo offline');
    } catch (e) {
      setState(() => _isLoadingOfflineUsers = false);
      _showError('Error cargando usuarios offline: $e');
    }
  }

  // 🆕 Cargar usuarios SOLO ONLINE (en backend pero no localmente)
  Future<void> _loadOnlineOnlyUsers() async {
    setState(() => _isLoadingOnlineUsers = true);
    try {
      print('[AdminPanel] ☁️ Buscando usuarios solo online...');

      // Verificar conexión
      final isOnline = await _backendService.isOnline();

      if (!isOnline) {
        setState(() {
          _onlineOnlyUsers = [];
          _isLoadingOnlineUsers = false;
        });
        _showError('Sin conexión. No se pueden cargar usuarios online');
        return;
      }

      // Obtener usuarios del backend
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://167.71.155.9:3001',
          connectTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      final response = await dio.get('/usuarios');

      if (response.statusCode != 200 || response.data is! List) {
        throw Exception('Respuesta inválida del backend');
      }

      final backendUsers = (response.data as List)
          .map((userData) => User.fromJson(userData as Map<String, dynamic>))
          .toList();

      // Obtener usuarios locales
      final localUsers = await _dbService.getAllUsers();
      final localIds = localUsers.map((u) => u.identificadorUnico).toSet();

      // Filtrar usuarios que SOLO están en backend (no localmente)
      final onlineOnly = backendUsers.where((user) {
        return !localIds.contains(user.identificadorUnico);
      }).toList();

      setState(() {
        _onlineOnlyUsers = onlineOnly;
        _isLoadingOnlineUsers = false;
      });

      print(
        '[AdminPanel] ☁️ ${onlineOnly.length} usuarios solo online encontrados',
      );
      _showSuccess('${onlineOnly.length} usuarios solo online');
    } catch (e) {
      setState(() => _isLoadingOnlineUsers = false);
      _showError('Error cargando usuarios online: $e');
    }
  }

  // 🆕 Cargar usuarios SINCRONIZADOS (en ambos lados: local Y backend)
  Future<void> _loadSyncedUsers() async {
    setState(() => _isLoadingSyncedUsers = true);
    try {
      print('[AdminPanel] 🔄 Buscando usuarios sincronizados...');

      // Obtener usuarios locales
      final localUsers = await _dbService.getAllUsers();

      // Verificar conexión
      final isOnline = await _backendService.isOnline();

      if (!isOnline) {
        setState(() {
          _syncedUsers = [];
          _isLoadingSyncedUsers = false;
        });
        _showError('Sin conexión. No se puede verificar sincronización');
        return;
      }

      // Obtener usuarios del backend
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://167.71.155.9:3001',
          connectTimeout: Duration(seconds: 10),
          receiveTimeout: Duration(seconds: 10),
        ),
      );

      final response = await dio.get('/usuarios');

      if (response.statusCode != 200 || response.data is! List) {
        throw Exception('Respuesta inválida del backend');
      }

      final backendUsers = (response.data as List)
          .map((userData) => User.fromJson(userData as Map<String, dynamic>))
          .toList();

      final backendIds = backendUsers.map((u) => u.identificadorUnico).toSet();

      // Filtrar usuarios que están en AMBOS lados (sincronizados)
      final synced = localUsers.where((user) {
        return backendIds.contains(user.identificadorUnico);
      }).toList();

      setState(() {
        _syncedUsers = synced;
        _isLoadingSyncedUsers = false;
      });

      print(
        '[AdminPanel] 🔄 ${synced.length} usuarios sincronizados encontrados',
      );
      _showSuccess('${synced.length} usuarios sincronizados');
    } catch (e) {
      setState(() => _isLoadingSyncedUsers = false);
      _showError('Error cargando usuarios sincronizados: $e');
    }
  }

  Future<void> _deleteUser(String identificador) async {
    try {
      print('[AdminPanel] 🗑️ Eliminando usuario: $identificador');

      // Verificar en qué categoría está el usuario
      final esOffline = _offlineOnlyUsers.any(
        (u) => u.identificadorUnico == identificador,
      );
      final esSincronizado = _syncedUsers.any(
        (u) => u.identificadorUnico == identificador,
      );

      // 1️⃣ Si es SOLO LOCAL → Eliminar solo de SQLite (más rápido)
      if (esOffline) {
        print('[AdminPanel] 📱 Usuario solo local, eliminando de SQLite...');
        await _dbService.deleteUser(identificador);
        _showSuccess('✅ Usuario local eliminado');
      }
      // 2️⃣ Si es SINCRONIZADO o SOLO NUBE → Eliminar del backend + local
      else {
        print('[AdminPanel] ☁️ Usuario en nube, eliminando...');

        // Verificar conexión
        final isOnline = await _backendService.isOnline();

        if (!isOnline) {
          // Sin conexión: solo eliminar local
          print('[AdminPanel] ⚠️ Sin conexión, eliminando solo local');
          await _dbService.deleteUser(identificador);
          _showError('⚠️ Sin conexión. Eliminado solo localmente');
        } else {
          // Con conexión: eliminar en backend
          try {
            await _backendService.eliminarUsuario(identificador: identificador);
            print('[AdminPanel] ✅ Usuario eliminado del backend');

            // También eliminar local si existe
            if (esSincronizado) {
              await _dbService.deleteUser(identificador);
              print('[AdminPanel] ✅ Usuario eliminado también local');
            }

            _showSuccess('✅ Usuario eliminado exitosamente');
          } catch (e) {
            // Error en backend: eliminar solo local
            print('[AdminPanel] ❌ Error en backend: $e');
            await _dbService.deleteUser(identificador);
            _showError('⚠️ Error en backend. Eliminado solo localmente');
          }
        }
      }

      // Recargar todas las listas
      await Future.wait([
        _loadOfflineOnlyUsers(),
        _loadOnlineOnlyUsers(),
        _loadSyncedUsers(),
      ]);
    } catch (e) {
      print('[AdminPanel] ❌ Error eliminando usuario: $e');
      _showError('❌ Error eliminando usuario: $e');
    }
  }

  Future<void> _restoreUser(String identificador) async {
    try {
      print('[AdminPanel] ♻️ Restaurando usuario: $identificador');

      // Verificar en qué categoría está el usuario
      final esOffline = _offlineOnlyUsers.any(
        (u) => u.identificadorUnico == identificador,
      );
      final esSincronizado = _syncedUsers.any(
        (u) => u.identificadorUnico == identificador,
      );

      // 1️⃣ Si es SOLO LOCAL → Restaurar solo de SQLite (más rápido)
      if (esOffline) {
        print('[AdminPanel] 📱 Usuario solo local, restaurando en SQLite...');
        await _dbService.restoreUser(identificador);
        _showSuccess('✅ Usuario local restaurado');
      }
      // 2️⃣ Si es SINCRONIZADO o SOLO NUBE → Restaurar del backend + local
      else {
        print('[AdminPanel] ☁️ Usuario en nube, restaurando...');

        // Verificar conexión
        final isOnline = await _backendService.isOnline();

        if (!isOnline) {
          // Sin conexión: solo restaurar local
          print('[AdminPanel] ⚠️ Sin conexión, restaurando solo local');
          await _dbService.restoreUser(identificador);
          _showError('⚠️ Sin conexión. Restaurado solo localmente');
        } else {
          // Con conexión: restaurar en backend
          try {
            await _backendService.restaurarUsuario(
              identificador: identificador,
            );
            print('[AdminPanel] ✅ Usuario restaurado en backend');

            // También restaurar local si existe
            if (esSincronizado) {
              await _dbService.restoreUser(identificador);
              print('[AdminPanel] ✅ Usuario restaurado también local');
            }

            _showSuccess('✅ Usuario restaurado exitosamente');
          } catch (e) {
            // Error en backend: restaurar solo local
            print('[AdminPanel] ❌ Error en backend: $e');
            await _dbService.restoreUser(identificador);
            _showError('⚠️ Error en backend. Restaurado solo localmente');
          }
        }
      }

      // Recargar todas las listas
      await Future.wait([
        _loadOfflineOnlyUsers(),
        _loadOnlineOnlyUsers(),
        _loadSyncedUsers(),
      ]);
    } catch (e) {
      print('[AdminPanel] ❌ Error restaurando usuario: $e');
      _showError('❌ Error restaurando usuario: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtener el ancho de la pantalla para responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, size: isWideScreen ? 32 : 24),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Panel de Administración',
                style: TextStyle(fontSize: isWideScreen ? 22 : 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Guardar configuraciones',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _confirmReset,
            tooltip: 'Restaurar valores por defecto',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _settings == null
          ? Center(child: Text('Error cargando configuraciones'))
          : _buildResponsiveSettings(isWideScreen),
    );
  }

  Widget _buildResponsiveSettings(bool isWideScreen) {
    if (isWideScreen) {
      // Diseño de 2 columnas para pantallas anchas
      return SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildSectionHeader('� Usuarios Solo Offline'),
                  _buildOfflineOnlyUsers(),
                  SizedBox(height: 24),
                  _buildSectionHeader('☁️ Usuarios Solo Online'),
                  _buildOnlineOnlyUsers(),
                  SizedBox(height: 24),
                  _buildSectionHeader('🔄 Usuarios Sincronizados'),
                  _buildSyncedUsers(),
                  SizedBox(height: 24),
                  _buildSectionHeader('�💬 Frases Dinámicas'),
                  _buildPhrasesManagement(),
                  SizedBox(height: 24),
                  _buildSectionHeader('🎨 Apariencia'),
                  _buildThemeToggle(),
                  SizedBox(height: 24),
                  _buildSectionHeader('🔄 Sincronización'),
                  _buildSyncSettings(),
                  SizedBox(height: 24),
                  _buildSectionHeader('🔒 Seguridad'),
                  _buildSecuritySettings(),
                ],
              ),
            ),
            SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  _buildSectionHeader('🌐 Red y API'),
                  _buildNetworkSettings(),
                  SizedBox(height: 24),
                  _buildSectionHeader('🐛 Debug y Desarrollo'),
                  _buildDebugSettings(),
                  SizedBox(height: 24),
                  _buildSectionHeader('📸 Biometría'),
                  _buildBiometricSettings(),
                  SizedBox(height: 24),
                  _buildSectionHeader('⚙️ Acciones'),
                  _buildActions(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // Diseño de 1 columna para pantallas pequeñas
      return _buildSettingsList();
    }
  }

  Widget _buildSettingsList() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSectionHeader('👥 Gestión de Usuarios'),
        _buildSectionHeader('� Usuarios Solo Offline'),
        _buildOfflineOnlyUsers(),
        SizedBox(height: 24),

        _buildSectionHeader('☁️ Usuarios Solo Online'),
        _buildOnlineOnlyUsers(),
        SizedBox(height: 24),

        _buildSectionHeader('🔄 Usuarios Sincronizados'),
        _buildSyncedUsers(),
        SizedBox(height: 24),

        _buildSectionHeader('�💬 Frases Dinámicas'),
        _buildPhrasesManagement(),
        SizedBox(height: 24),

        _buildSectionHeader('🎨 Apariencia'),
        _buildThemeToggle(),
        SizedBox(height: 24),

        _buildSectionHeader('🔄 Sincronización'),
        _buildSyncSettings(),
        SizedBox(height: 24),

        _buildSectionHeader('🔒 Seguridad'),
        _buildSecuritySettings(),
        SizedBox(height: 24),

        _buildSectionHeader('🌐 Red y API'),
        _buildNetworkSettings(),
        SizedBox(height: 24),

        _buildSectionHeader('🐛 Debug y Desarrollo'),
        _buildDebugSettings(),
        SizedBox(height: 24),

        _buildSectionHeader('📸 Biometría'),
        _buildBiometricSettings(),
        SizedBox(height: 24),

        _buildSectionHeader('⚙️ Acciones'),
        _buildActions(),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Card(
      child: SwitchListTile(
        title: Text('Modo Oscuro'),
        subtitle: Text(_settings!.isDarkMode ? 'Activado' : 'Desactivado'),
        secondary: Icon(
          _settings!.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        ),
        value: _settings!.isDarkMode,
        onChanged: (value) {
          setState(() {
            _settings = _settings!.copyWith(isDarkMode: value);
          });
        },
      ),
    );
  }

  Widget _buildSyncSettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Auto-sincronización'),
            subtitle: Text('Sincronizar automáticamente cuando hay conexión'),
            secondary: Icon(Icons.sync),
            value: _settings!.autoSyncEnabled,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(autoSyncEnabled: value);
              });
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.timer),
            title: Text('Intervalo de sincronización'),
            subtitle: Text('${_settings!.syncIntervalMinutes} minutos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.syncIntervalMinutes > 1) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          syncIntervalMinutes:
                              _settings!.syncIntervalMinutes - 1,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        syncIntervalMinutes: _settings!.syncIntervalMinutes + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.repeat),
            title: Text('Máximo de reintentos'),
            subtitle: Text('${_settings!.maxRetryAttempts} intentos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.maxRetryAttempts > 1) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          maxRetryAttempts: _settings!.maxRetryAttempts - 1,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        maxRetryAttempts: _settings!.maxRetryAttempts + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Requerir biometría'),
            subtitle: Text('Solicitar autenticación biométrica en login'),
            secondary: Icon(Icons.fingerprint),
            value: _settings!.biometricRequired,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(biometricRequired: value);
              });
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.lock_clock),
            title: Text('Timeout de sesión'),
            subtitle: Text('${_settings!.sessionTimeoutMinutes} minutos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.sessionTimeoutMinutes > 5) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          sessionTimeoutMinutes:
                              _settings!.sessionTimeoutMinutes - 5,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        sessionTimeoutMinutes:
                            _settings!.sessionTimeoutMinutes + 5,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.wifi_off),
            title: Text('Intervalo mensaje "sin conexión"'),
            subtitle: Text(
              '${_settings!.offlineMessageIntervalMinutes} minuto(s)',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.offlineMessageIntervalMinutes > 1) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          offlineMessageIntervalMinutes:
                              _settings!.offlineMessageIntervalMinutes - 1,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        offlineMessageIntervalMinutes:
                            _settings!.offlineMessageIntervalMinutes + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Intentos máximos de login'),
            subtitle: Text('${_settings!.maxLoginAttempts} intentos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.maxLoginAttempts > 1) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          maxLoginAttempts: _settings!.maxLoginAttempts - 1,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        maxLoginAttempts: _settings!.maxLoginAttempts + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkSettings() {
    return Card(
      child: Column(
        children: [
          // ✅ ACTUALIZADO: Configuración Backend Biométrico (PRINCIPAL)
          ListTile(
            leading: Icon(Icons.cloud, color: Colors.purple),
            title: Text('Backend Biométrico (Principal)'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IP: ${_settings!.backendIp}'),
                SizedBox(height: 4),
                Text(
                  'Endpoints:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  '• Registro Usuario: ${_settings!.backendIp}:${_settings!.backendPuertoOreja}/registrar_usuario',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                Text(
                  '• Registro Oreja: ${_settings!.backendIp}:${_settings!.backendPuertoOreja}/oreja/registrar',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                Text(
                  '• Autenticación Oreja: ${_settings!.backendIp}:${_settings!.backendPuertoOreja}/oreja/autenticar',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
                Text(
                  '• Registro Voz: ${_settings!.backendIp}:${_settings!.backendPuertoVoz}/voz/registrar',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                Text(
                  '• Autenticación Voz: ${_settings!.backendIp}:${_settings!.backendPuertoVoz}/voz/autenticar',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Servidor en la nube',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editBackendConfig(),
              tooltip: 'Configurar Backend',
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.timer_outlined),
            title: Text('Timeout de peticiones'),
            subtitle: Text('${_settings!.requestTimeoutSeconds} segundos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.requestTimeoutSeconds > 10) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          requestTimeoutSeconds:
                              _settings!.requestTimeoutSeconds - 10,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        requestTimeoutSeconds:
                            _settings!.requestTimeoutSeconds + 10,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(),
          SwitchListTile(
            title: Text('Permitir conexiones inseguras'),
            subtitle: Text('Permitir HTTP (solo para desarrollo)'),
            secondary: Icon(Icons.warning_amber),
            value: _settings!.allowInsecureConnections,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(
                  allowInsecureConnections: value,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugSettings() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: Text('Logs de debug'),
            subtitle: Text('Mostrar logs detallados en consola'),
            secondary: Icon(Icons.bug_report),
            value: _settings!.enableDebugLogs,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(enableDebugLogs: value);
              });
            },
          ),
          Divider(),
          SwitchListTile(
            title: Text('Indicador de red'),
            subtitle: Text('Mostrar badge de conectividad'),
            secondary: Icon(Icons.wifi),
            value: _settings!.showNetworkIndicator,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(showNetworkIndicator: value);
              });
            },
          ),
          Divider(),
          SwitchListTile(
            title: Text('Estado de sincronización'),
            subtitle: Text('Mostrar banner de sincronización'),
            secondary: Icon(Icons.sync_alt),
            value: _settings!.showSyncStatus,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(showSyncStatus: value);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricSettings() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.photo_camera),
            title: Text('Calidad mínima de foto'),
            subtitle: Text('${_settings!.minPhotoQuality}%'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.minPhotoQuality > 10) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          minPhotoQuality: _settings!.minPhotoQuality - 10,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    if (_settings!.minPhotoQuality < 100) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          minPhotoQuality: _settings!.minPhotoQuality + 10,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.mic),
            title: Text('Duración de grabación de audio'),
            subtitle: Text('${_settings!.audioRecordingDuration} segundos'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: () {
                    if (_settings!.audioRecordingDuration > 3) {
                      setState(() {
                        _settings = _settings!.copyWith(
                          audioRecordingDuration:
                              _settings!.audioRecordingDuration - 1,
                        );
                      });
                    }
                  },
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () {
                    setState(() {
                      _settings = _settings!.copyWith(
                        audioRecordingDuration:
                            _settings!.audioRecordingDuration + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(),
          SwitchListTile(
            title: Text('Permitir múltiples registros'),
            subtitle: Text('Permitir registrar mismo usuario varias veces'),
            secondary: Icon(Icons.people),
            value: _settings!.allowMultipleRegistrations,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(
                  allowMultipleRegistrations: value,
                );
              });
            },
          ),
          Divider(),
          SwitchListTile(
            title: Text('Validación de orejas con IA'),
            subtitle: Text(
              'Usar TensorFlow Lite para validar que sean orejas reales',
            ),
            secondary: Icon(Icons.psychology, color: Colors.purple),
            value: _settings!.enableEarValidation,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(enableEarValidation: value);
              });
            },
          ),
          Divider(),
          SwitchListTile(
            title: Text('Validación de campos en registro'),
            subtitle: Text(
              'Bloquear el botón "Siguiente" hasta llenar todos los campos obligatorios',
            ),
            secondary: Icon(Icons.fact_check, color: Colors.orange),
            value: _settings!.requireAllFieldsInRegistration,
            onChanged: (value) {
              setState(() {
                _settings = _settings!.copyWith(
                  requireAllFieldsInRegistration: value,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.file_download, color: Colors.blue),
            title: Text('Exportar configuraciones'),
            subtitle: Text('Guardar configuraciones como JSON'),
            onTap: _exportSettings,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.file_upload, color: Colors.green),
            title: Text('Importar configuraciones'),
            subtitle: Text('Cargar configuraciones desde JSON'),
            onTap: _importSettings,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.vpn_key, color: Colors.orange),
            title: Text('Generar hash de contraseña'),
            subtitle: Text('Crear hash para nueva contraseña maestra'),
            onTap: _generatePasswordHash,
          ),
        ],
      ),
    );
  }

  // ✅ Editar configuración del backend biométrico
  Future<void> _editBackendConfig() async {
    final ipController = TextEditingController(text: _settings!.backendIp);
    final puertoOrejaController = TextEditingController(
      text: _settings!.backendPuertoOreja.toString(),
    );
    final puertoVozController = TextEditingController(
      text: _settings!.backendPuertoVoz.toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud, color: Colors.purple, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Configurar Backend', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Servidor en la Nube',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: ipController,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'IP del Servidor',
                    labelStyle: TextStyle(fontSize: 12),
                    hintText: '167.71.155.9',
                    hintStyle: TextStyle(fontSize: 12),
                    prefixIcon: Icon(Icons.dns, size: 20),
                    helperText: 'Ej: 167.71.155.9',
                    helperStyle: TextStyle(fontSize: 11),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: puertoOrejaController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Puerto Oreja',
                    labelStyle: TextStyle(fontSize: 12),
                    hintText: '8080',
                    hintStyle: TextStyle(fontSize: 12),
                    prefixIcon: Icon(Icons.hearing, size: 20),
                    helperText: 'Servicio de oreja',
                    helperStyle: TextStyle(fontSize: 11),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: puertoVozController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Puerto Voz',
                    labelStyle: TextStyle(fontSize: 12),
                    hintText: '8081',
                    hintStyle: TextStyle(fontSize: 12),
                    prefixIcon: Icon(Icons.mic, size: 20),
                    helperText: 'Servicio de voz',
                    helperStyle: TextStyle(fontSize: 11),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Endpoints generados:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Registro Usuario:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'http://${ipController.text}:${puertoOrejaController.text}/registrar_usuario',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Registro Oreja:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'http://${ipController.text}:${puertoOrejaController.text}/oreja/registrar',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Registro Voz:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'http://${ipController.text}:${puertoVozController.text}/voz/registrar',
                        style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'ip': ipController.text.trim(),
                'puertoOreja': int.tryParse(puertoOrejaController.text) ?? 8080,
                'puertoVoz': int.tryParse(puertoVozController.text) ?? 8081,
              });
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _settings = _settings!.copyWith(
          backendIp: result['ip'],
          backendPuertoOreja: result['puertoOreja'],
          backendPuertoVoz: result['puertoVoz'],
        );
      });

      await _saveSettings();

      _showSuccess(
        'Backend actualizado:\n'
        '• Usuario: http://${result['ip']}:${result['puertoOreja']}/registrar_usuario\n'
        '• Oreja: http://${result['ip']}:${result['puertoOreja']}/oreja/registrar\n'
        '• Voz: http://${result['ip']}:${result['puertoVoz']}/voz/registrar',
      );
    }
  }

  Future<void> _exportSettings() async {
    try {
      final json = await _adminService.exportSettings();
      await Clipboard.setData(ClipboardData(text: json));
      _showSuccess('Configuraciones copiadas al portapapeles');
    } catch (e) {
      _showError('Error exportando: $e');
    }
  }

  Future<void> _importSettings() async {
    final controller = TextEditingController();

    final json = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Importar Configuraciones'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Pegar JSON',
            hintText: '{"isDarkMode": true, ...}',
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Importar'),
          ),
        ],
      ),
    );

    if (json != null && json.isNotEmpty) {
      try {
        await _adminService.importSettings(json);
        await _loadSettings();
        _showSuccess('Configuraciones importadas exitosamente');
      } catch (e) {
        _showError('Error importando: $e');
      }
    }
  }

  Future<void> _generatePasswordHash() async {
    final controller = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Generar Hash'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            hintText: 'Ingresa la contraseña',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Generar'),
          ),
        ],
      ),
    );

    if (password != null && password.isNotEmpty) {
      final hash = _adminService.generatePasswordHash(password);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Hash Generado'),
          content: SelectableText(hash),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                Navigator.pop(context);
                _showSuccess('Hash copiado al portapapeles');
              },
              child: Text('Copiar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  // ✅ Gestión de Usuarios
  Future<void> _confirmDeleteUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar a ${user.nombres} ${user.apellidos}?\n\nID: ${user.identificadorUnico}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteUser(user.identificadorUnico);
    }
  }

  Future<void> _confirmRestoreUser(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('✅ Confirmar Restauración'),
        content: Text(
          '¿Estás seguro de que deseas restaurar a ${user.nombres} ${user.apellidos}?\n\nID: ${user.identificadorUnico}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _restoreUser(user.identificadorUnico);
    }
  }

  // 🗑️ ELIMINAR PERMANENTEMENTE usuario offline
  Future<void> _confirmDeleteOfflineUserPermanently(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🗑️ Eliminar Permanentemente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar PERMANENTEMENTE a:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('${user.nombres} ${user.apellidos}'),
            Text('ID: ${user.identificadorUnico}'),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ ADVERTENCIA:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Se eliminarán TODOS los datos locales\n'
                    '• Se eliminarán las credenciales biométricas\n'
                    '• Esta acción NO se puede deshacer\n'
                    '• Solo afecta la base de datos LOCAL',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar Permanentemente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deleteOfflineUserPermanently(user.identificadorUnico);
    }
  }

  Future<void> _deleteOfflineUserPermanently(String identificador) async {
    try {
      print(
        '[AdminPanel] 🗑️💀 ELIMINACIÓN PERMANENTE de usuario offline: $identificador',
      );

      // Usar el método del servicio que hace todo el trabajo
      await _dbService.deleteUserPermanently(identificador);

      _showSuccess('✅ Usuario offline eliminado permanentemente');

      // Recargar lista
      await _loadOfflineOnlyUsers();
    } catch (e) {
      print('[AdminPanel] ❌ Error eliminando permanentemente: $e');
      _showError('❌ Error: $e');
    }
  }

  // =============== USUARIOS SOLO OFFLINE ===============

  Widget _buildOfflineOnlyUsers() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.phonelink_off, color: Colors.orange),
            title: Text('Usuarios Solo Offline'),
            subtitle: Text(
              _offlineOnlyUsers.isEmpty
                  ? 'No hay usuarios cargados'
                  : '${_offlineOnlyUsers.length} usuario(s) registrados solo localmente',
            ),
            trailing: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadOfflineOnlyUsers,
              tooltip: 'Cargar usuarios offline',
            ),
          ),
          if (_isLoadingOfflineUsers)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_offlineOnlyUsers.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No hay usuarios solo offline',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Estos son usuarios registrados localmente pero no sincronizados al backend',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadOfflineOnlyUsers,
                    icon: Icon(Icons.search),
                    label: Text('Buscar Usuarios Offline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: _offlineOnlyUsers.length,
                itemBuilder: (context, index) {
                  final user = _offlineOnlyUsers[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.phonelink_off, color: Colors.white),
                    ),
                    title: Text('${user.nombres} ${user.apellidos}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${user.identificadorUnico}'),
                        Text(
                          '📱 Solo en dispositivo local',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (marcar como eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.orange,
                            ),
                            tooltip: 'Marcar como eliminado',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de eliminar PERMANENTEMENTE (solo offline)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete_forever, color: Colors.red),
                            tooltip: 'Eliminar PERMANENTEMENTE',
                            onPressed: () =>
                                _confirmDeleteOfflineUserPermanently(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // =============== USUARIOS SOLO ONLINE ===============

  Widget _buildOnlineOnlyUsers() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.cloud, color: Colors.blue),
            title: Text('Usuarios Solo Online'),
            subtitle: Text(
              _onlineOnlyUsers.isEmpty
                  ? 'No hay usuarios cargados'
                  : '${_onlineOnlyUsers.length} usuario(s) solo en el backend',
            ),
            trailing: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadOnlineOnlyUsers,
              tooltip: 'Cargar usuarios online',
            ),
          ),
          if (_isLoadingOnlineUsers)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_onlineOnlyUsers.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.cloud_done, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No hay usuarios solo online',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Estos son usuarios en el backend pero no descargados localmente',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadOnlineOnlyUsers,
                    icon: Icon(Icons.search),
                    label: Text('Buscar Usuarios Online'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: _onlineOnlyUsers.length,
                itemBuilder: (context, index) {
                  final user = _onlineOnlyUsers[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.cloud, color: Colors.white),
                    ),
                    title: Text('${user.nombres} ${user.apellidos}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${user.identificadorUnico}'),
                        Text(
                          '☁️ Solo en backend',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (solo si no está eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar usuario',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // =============== USUARIOS SINCRONIZADOS ===============

  Widget _buildSyncedUsers() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.sync, color: Colors.green),
            title: Text('Usuarios Sincronizados'),
            subtitle: Text(
              _syncedUsers.isEmpty
                  ? 'No hay usuarios cargados'
                  : '${_syncedUsers.length} usuario(s) en local y backend',
            ),
            trailing: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadSyncedUsers,
              tooltip: 'Cargar usuarios sincronizados',
            ),
          ),
          if (_isLoadingSyncedUsers)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_syncedUsers.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.sync_disabled, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No hay usuarios sincronizados',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Estos son usuarios que existen tanto localmente como en el backend',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadSyncedUsers,
                    icon: Icon(Icons.search),
                    label: Text('Buscar Usuarios Sincronizados'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: _syncedUsers.length,
                itemBuilder: (context, index) {
                  final user = _syncedUsers[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.sync, color: Colors.white),
                    ),
                    title: Text('${user.nombres} ${user.apellidos}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${user.identificadorUnico}'),
                        Text(
                          '✅ Sincronizado (Local + Backend)',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón de eliminar (solo si no está eliminado)
                        if (user.estado != 'eliminado')
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar usuario',
                            onPressed: () => _confirmDeleteUser(user),
                          ),
                        // Botón de restaurar (solo si está eliminado)
                        if (user.estado == 'eliminado')
                          IconButton(
                            icon: Icon(Icons.restore, color: Colors.blue),
                            tooltip: 'Restaurar usuario',
                            onPressed: () => _confirmRestoreUser(user),
                          ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // =============== GESTIÓN DE FRASES DINÁMICAS ===============

  Future<void> _loadFrases() async {
    setState(() => _isLoadingFrases = true);
    try {
      final frases = await _backendService.listarFrases();
      setState(() {
        _frases = frases;
        _isLoadingFrases = false;
      });
    } catch (e) {
      setState(() => _isLoadingFrases = false);
      _showError('Error cargando frases: $e');
    }
  }

  Future<void> _addFrase() async {
    final controller = TextEditingController();

    final frase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('➕ Agregar Frase'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Frase',
            hintText: 'Ej: Soy una llave para un sistema al cual es mi voz',
          ),
          maxLines: 3,
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Agregar'),
          ),
        ],
      ),
    );

    if (frase != null && frase.trim().isNotEmpty) {
      try {
        await _backendService.agregarFrase(frase: frase.trim());
        _showSuccess('Frase agregada exitosamente');
        await _loadFrases();
      } catch (e) {
        _showError('Error agregando frase: $e');
      }
    }
  }

  Future<void> _toggleFraseEstado(int idFrase, bool activo) async {
    try {
      await _backendService.cambiarEstadoFrase(id: idFrase, activo: activo);
      _showSuccess(activo ? 'Frase activada' : 'Frase desactivada');
      await _loadFrases();
    } catch (e) {
      _showError('Error cambiando estado: $e');
    }
  }

  Future<void> _confirmDeleteFrase(Map<String, dynamic> frase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Confirmar Eliminación'),
        content: Text(
          '¿Estás seguro de que deseas eliminar esta frase?\n\n"${frase['frase']}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _backendService.eliminarFrase(id: frase['id_texto']);
        _showSuccess('Frase eliminada exitosamente');
        await _loadFrases();
      } catch (e) {
        _showError('Error eliminando frase: $e');
      }
    }
  }

  Widget _buildPhrasesManagement() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.mic_none, color: Colors.purple),
            title: Text('Frases de Autenticación por Voz'),
            subtitle: Text(
              _frases.isEmpty
                  ? 'No hay frases cargadas'
                  : '${_frases.length} frase(s) disponible(s)',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.green),
                  onPressed: _addFrase,
                  tooltip: 'Agregar frase',
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadFrases,
                  tooltip: 'Recargar frases',
                ),
              ],
            ),
          ),
          if (_isLoadingFrases)
            Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_frases.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.speaker_notes_off, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No hay frases registradas',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadFrases,
                    icon: Icon(Icons.refresh),
                    label: Text('Cargar Frases'),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: _frases.length,
                itemBuilder: (context, index) {
                  final frase = _frases[index];
                  final isActivo = frase['estado_texto'] == 'activo';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    elevation: isActivo ? 2 : 0,
                    color: isActivo ? null : Colors.grey[200],
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActivo ? Colors.green : Colors.grey,
                        child: Text(
                          '${frase['id_texto']}',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        frase['frase'] ?? '',
                        style: TextStyle(
                          color: isActivo ? null : Colors.grey[600],
                          fontStyle: isActivo
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      subtitle: Text(
                        'Estado: ${frase['estado_texto']}',
                        style: TextStyle(
                          color: isActivo ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: isActivo,
                            onChanged: (value) =>
                                _toggleFraseEstado(frase['id_texto'], value),
                            activeColor: Colors.green,
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar frase',
                            onPressed: () => _confirmDeleteFrase(frase),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
