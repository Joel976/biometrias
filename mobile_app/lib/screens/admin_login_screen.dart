import 'package:flutter/material.dart';
import '../services/admin_settings_service.dart';
import 'admin_panel_screen.dart';

/// Pantalla de autenticación para acceder al panel de administración
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _adminService = AdminSettingsService();

  bool _obscurePassword = true;
  bool _obscureSecretKey = true;
  bool _isLoading = false;
  int _failedAttempts = 0;
  final int _maxAttempts = 5;

  @override
  void dispose() {
    _passwordController.dispose();
    _secretKeyController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_failedAttempts >= _maxAttempts) {
      _showError('Demasiados intentos fallidos. Espera 1 minuto.');
      await Future.delayed(Duration(minutes: 1));
      setState(() => _failedAttempts = 0);
      return;
    }

    setState(() => _isLoading = true);

    // Simular pequeño delay para seguridad
    await Future.delayed(Duration(milliseconds: 500));

    final isValid = _adminService.authenticate(
      _passwordController.text,
      _secretKeyController.text,
    );

    setState(() => _isLoading = false);

    if (isValid) {
      // Autenticación exitosa
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminPanelScreen()),
      );
    } else {
      // Autenticación fallida
      setState(() => _failedAttempts++);

      _showError(
        'Credenciales incorrectas. Intento ${_failedAttempts}/$_maxAttempts',
      );

      // Limpiar campos
      _passwordController.clear();
      _secretKeyController.clear();
    }
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

  void _showHint() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('Credenciales por Defecto'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para modo de desarrollo/testing:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildCredentialRow('Contraseña', 'admin'),
            SizedBox(height: 8),
            _buildCredentialRow('Clave Secreta', 'password'),
            SizedBox(height: 16),
            Text(
              '⚠️ Cambiar estas credenciales en producción',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acceso Administrativo'),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHint,
            tooltip: 'Ver credenciales de prueba',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icono
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 64,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(height: 32),

                // Título
                Text(
                  'Panel de Administración',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Ingresa tus credenciales de administrador',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                SizedBox(height: 40),

                // Campo de contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña Maestra',
                    hintText: 'Ingresa la contraseña maestra',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa la contraseña';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _authenticate(),
                ),
                SizedBox(height: 20),

                // Campo de clave secreta
                TextFormField(
                  controller: _secretKeyController,
                  obscureText: _obscureSecretKey,
                  decoration: InputDecoration(
                    labelText: 'Clave Secreta',
                    hintText: 'Ingresa la clave secreta',
                    prefixIcon: Icon(Icons.vpn_key),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecretKey
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscureSecretKey = !_obscureSecretKey);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa la clave secreta';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _authenticate(),
                ),
                SizedBox(height: 32),

                // Botón de login
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _authenticate,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login),
                              SizedBox(width: 8),
                              Text(
                                'Acceder al Panel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 16),

                // Intentos restantes
                if (_failedAttempts > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Intentos fallidos: $_failedAttempts/$_maxAttempts',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 24),

                // Info de seguridad
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Solo personal autorizado puede acceder a esta sección',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
