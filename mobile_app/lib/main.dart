import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/sync_manager.dart';
import 'services/admin_settings_service.dart';
import 'models/admin_settings.dart';
import 'widgets/connectivity_status_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar configuraciones de administrador
  final adminService = AdminSettingsService();
  final adminSettings = await adminService.loadSettings();

  runApp(BiometricApp(adminSettings: adminSettings));
}

class BiometricApp extends StatefulWidget {
  final AdminSettings adminSettings;

  const BiometricApp({Key? key, required this.adminSettings}) : super(key: key);

  @override
  State<BiometricApp> createState() => _BiometricAppState();
}

class _BiometricAppState extends State<BiometricApp> {
  late SyncManager _syncManager;
  late AdminSettings _currentSettings;
  final _adminService = AdminSettingsService();

  @override
  void initState() {
    super.initState();
    _currentSettings = widget.adminSettings;
    _syncManager = SyncManager();
    _syncManager.startAutoSync();

    // Escuchar cambios en las configuraciones cada 2 segundos
    _listenToSettingsChanges();
  }

  void _listenToSettingsChanges() {
    // Revisar cambios en configuraciones periódicamente
    Future.delayed(Duration(seconds: 2), () async {
      if (!mounted) return;

      try {
        final settings = await _adminService.loadSettings();

        if (mounted && settings.isDarkMode != _currentSettings.isDarkMode) {
          setState(() {
            _currentSettings = settings;
          });

          if (settings.enableDebugLogs) {
            print(
              '[App] 🎨 Tema cambiado a: ${settings.isDarkMode ? "Oscuro" : "Claro"}',
            );
          }
        }
      } catch (e) {
        if (_currentSettings.enableDebugLogs) {
          print('[App] ⚠️ Error cargando configuraciones: $e');
        }
      }

      _listenToSettingsChanges(); // Continuar escuchando
    });
  }

  @override
  void dispose() {
    _syncManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiometricAuth',

      // Tema claro
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      // Tema oscuro
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      // Aplicar tema según configuración de admin
      themeMode: _currentSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // Ocultar el banner de DEBUG
      debugShowCheckedModeBanner: false,
      // Usamos builder para envolver TODAS las rutas/pantallas con el widget
      builder: (context, child) {
        return ConnectivityStatusWidget(
          syncManager: _syncManager,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (ctx) => LoginScreen(),
        '/home': (ctx) => const HomeScreen(),
      },
    );
  }
}
