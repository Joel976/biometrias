import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  print('Hash de "admin": ${hashString('admin')}');
  print('Hash de "password": ${hashString('password')}');

  // Verificar contra los hashes en el código
  const masterHash =
      '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918';
  const secretHash =
      '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8';

  print('\n✓ Hash de "admin" coincide: ${hashString('admin') == masterHash}');
  print(
    '✓ Hash de "password" coincide: ${hashString('password') == secretHash}',
  );
}
