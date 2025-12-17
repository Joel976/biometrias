import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/admin_settings_service.dart';
import '../models/admin_settings.dart';
import '../config/api_config.dart';

/// Pantalla del Panel de Administración
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _adminService = AdminSettingsService();
  AdminSettings? _settings;
  bool _isLoading = true;

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
          ListTile(
            leading: Icon(Icons.api, color: Colors.blue),
            title: Text('URL de la API'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_settings!.apiBaseUrl),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'Presiona editar para cambiar',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _editApiUrl(),
              tooltip: 'Cambiar URL de la API',
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

  Future<void> _editApiUrl() async {
    final controller = TextEditingController(text: _settings!.apiBaseUrl);

    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar URL de la API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'URL Base',
                hintText: 'http://ejemplo.com:3000/api',
                helperText: 'Ejemplo: http://192.168.1.100:3000/api',
              ),
            ),
            SizedBox(height: 8),
            Text(
              '⚠️ La configuración se guardará automáticamente',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Guardar'),
          ),
        ],
      ),
    );

    if (newUrl != null &&
        newUrl.isNotEmpty &&
        newUrl != _settings!.apiBaseUrl) {
      setState(() {
        _settings = _settings!.copyWith(apiBaseUrl: newUrl);
      });

      // Guardar automáticamente después de cambiar URL
      await _saveSettings();

      _showSuccess('URL de la API actualizada a: $newUrl');
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
}
