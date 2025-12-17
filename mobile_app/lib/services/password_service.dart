import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Servicio de gestión segura de contraseñas
/// - Hash con salt (PBKDF2 simulado usando SHA-256 iterado)
/// - Nunca almacena passwords en plaintext
/// - Válido para online y offline
class PasswordService {
  static final PasswordService _instance = PasswordService._internal();

  factory PasswordService() {
    return _instance;
  }

  PasswordService._internal();

  // Número de iteraciones para el hash (PBKDF2-like)
  static const int HASH_ITERATIONS = 100000;

  /// Generar un salt aleatorio (16 bytes = 32 caracteres hex)
  static String generateSalt() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    return sha256.convert(utf8.encode(random)).toString().substring(0, 32);
  }

  /// Hash seguro de contraseña con salt
  /// Retorna: "salt$hashedPassword" para guardar en BD
  String hashPassword(String password) {
    if (password.isEmpty) throw Exception('Contraseña no puede estar vacía');

    final salt = generateSalt();
    final hashed = _pbkdf2Like(password, salt);

    // Formato: salt$hash (para poder verificar después)
    return '$salt\$${hashed}';
  }

  /// PBKDF2 simulado usando SHA-256 iterado
  /// En producción usar librerías especializadas (pointycastle, argon2, etc)
  String _pbkdf2Like(String password, String salt) {
    String hash = password;

    // Iterar SHA-256 N veces con salt
    for (int i = 0; i < HASH_ITERATIONS; i++) {
      hash = sha256
          .convert(utf8.encode('$hash$salt'))
          .toString()
          .substring(0, 64);
    }

    return hash;
  }

  /// Verificar contraseña contra hash almacenado
  /// Retorna: true si contraseña es correcta, false en caso contrario
  bool verifyPassword(String password, String storedHash) {
    if (storedHash.isEmpty || !storedHash.contains('\$')) {
      return false;
    }

    try {
      // Extraer salt y hash del formato "salt$hash"
      final parts = storedHash.split('\$');
      if (parts.length != 2) return false;

      final salt = parts[0];
      final originalHash = parts[1];

      // Hashear la contraseña ingresada con el mismo salt
      final inputHash = _pbkdf2Like(password, salt);

      // Comparar (usando comparison constante para evitar timing attacks)
      return _constantTimeCompare(inputHash, originalHash);
    } catch (e) {
      print('[PasswordService] Error verificando password: $e');
      return false;
    }
  }

  /// Comparación de tiempo constante (evita timing attacks)
  /// Siempre tarda el mismo tiempo sin importar dónde falle
  bool _constantTimeCompare(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }

  /// Generar contraseña temporal/aleatoria (para testing)
  static String generateRandomPassword() {
    final chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().microsecondsSinceEpoch;

    String password = '';
    for (int i = 0; i < 12; i++) {
      password += chars[(random + i) % chars.length];
    }
    return password;
  }

  /// Validar fortaleza de contraseña
  /// Retorna: (esValida, mensaje)
  (bool, String) validatePasswordStrength(String password) {
    if (password.isEmpty) {
      return (false, 'Contraseña no puede estar vacía');
    }

    if (password.length < 6) {
      return (false, 'Contraseña debe tener al menos 6 caracteres');
    }

    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$%^&*]'));

    // Requerimientos mínimos (al menos 3 de 4)
    final meetsRequirements =
        [
          hasUppercase,
          hasLowercase,
          hasNumbers,
          hasSpecial,
        ].where((req) => req).length >=
        3;

    if (!meetsRequirements) {
      return (
        false,
        'Contraseña debe contener mayúsculas, minúsculas, números y caracteres especiales',
      );
    }

    return (true, 'Contraseña fuerte ✓');
  }
}
