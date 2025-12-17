import 'package:flutter_test/flutter_test.dart';
import 'package:biometrics_app/services/admin_settings_service.dart';

void main() {
  group('AdminSettingsService Authentication Tests', () {
    final adminService = AdminSettingsService();

    test('Autenticación exitosa con credenciales correctas', () {
      final result = adminService.authenticate('admin', 'password');
      expect(result, true);
    });

    test('Autenticación fallida con contraseña incorrecta', () {
      final result = adminService.authenticate('wrong', 'password');
      expect(result, false);
    });

    test('Autenticación fallida con clave secreta incorrecta', () {
      final result = adminService.authenticate('admin', 'wrong');
      expect(result, false);
    });

    test('Autenticación fallida con ambas credenciales incorrectas', () {
      final result = adminService.authenticate('wrong', 'wrong');
      expect(result, false);
    });

    test('Autenticación fallida con credenciales vacías', () {
      final result = adminService.authenticate('', '');
      expect(result, false);
    });
  });
}
