import 'package:flutter/material.dart';
import 'admin_login_screen.dart';

/// Widget de botón secreto para acceder al panel de administración
/// Se puede colocar en cualquier pantalla
class AdminAccessButton extends StatefulWidget {
  final bool showLabel;

  const AdminAccessButton({Key? key, this.showLabel = false}) : super(key: key);

  @override
  State<AdminAccessButton> createState() => _AdminAccessButtonState();
}

class _AdminAccessButtonState extends State<AdminAccessButton> {
  int _tapCount = 0;
  DateTime? _lastTap;

  // Requiere 7 taps en menos de 3 segundos para acceder
  final int _requiredTaps = 7;
  final Duration _tapWindow = Duration(seconds: 3);

  void _handleTap() {
    final now = DateTime.now();

    // Reset si pasó mucho tiempo desde el último tap
    if (_lastTap != null && now.difference(_lastTap!) > _tapWindow) {
      _tapCount = 0;
    }

    _lastTap = now;
    _tapCount++;

    if (_tapCount >= _requiredTaps) {
      _tapCount = 0;
      _openAdminLogin();
    } else {
      // Feedback visual sutil
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_requiredTaps - _tapCount} taps más...'),
          duration: Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
          width: 150,
        ),
      );
    }
  }

  void _openAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdminLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showLabel) {
      return ElevatedButton.icon(
        onPressed: _handleTap,
        icon: Icon(Icons.admin_panel_settings),
        label: Text('Admin'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade300),
      );
    }

    // Botón invisible/discreto (tap secret)
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: 50,
        height: 50,
        color: Colors.transparent,
        child: Icon(Icons.settings, color: Colors.grey.shade400, size: 24),
      ),
    );
  }
}
