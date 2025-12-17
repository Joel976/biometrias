import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class DatabaseConfig {
  static const String dbName = 'biometrics_local.db';
  static const int dbVersion =
      3; // bump v3: Eliminar datos locales (migración 005 en PostgreSQL, contraseña removida)

  // Clave de cifrado para SQLCipher (en producción usar key management seguro)
  static const String encryptionPassword = 'your_secure_encryption_key_here';

  static final DatabaseConfig _instance = DatabaseConfig._internal();

  Database? _database;

  factory DatabaseConfig() {
    return _instance;
  }

  DatabaseConfig._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Tabla de usuarios locales
    await db.execute('''
      CREATE TABLE usuarios (
        id_usuario INTEGER PRIMARY KEY,
        nombres TEXT,
        apellidos TEXT,
        identificador_unico TEXT UNIQUE,
        estado TEXT,
        local_uuid TEXT UNIQUE,
        remote_id INTEGER
      )
    ''');

    // Tabla de credenciales biométricas locales
    await db.execute('''
      CREATE TABLE credenciales_biometricas (
        id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_biometria TEXT,
        template BLOB,
        validez_hasta TEXT,
        version_algoritmo TEXT,
        local_uuid TEXT UNIQUE,
        remote_id INTEGER,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Tabla de frases dinámicas activas
    await db.execute('''
      CREATE TABLE textos_dinamicos_audio (
        id_texto INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        frase TEXT,
        estado_texto TEXT,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Validaciones realizadas
    await db.execute('''
      CREATE TABLE validaciones_biometricas (
        id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_biometria TEXT,
        resultado TEXT,
        modo_validacion TEXT,
        timestamp TEXT,
        ubicacion_gps TEXT,
        puntuacion_confianza REAL,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Sincronización de datos pendientes
    await db.execute('''
      CREATE TABLE sincronizaciones (
        id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        fecha_ultima_sync TEXT,
        tipo_sync TEXT,
        estado_sync TEXT,
        cantidad_items INTEGER,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Cola de sincronización
    await db.execute('''
      CREATE TABLE cola_sincronizacion (
        id_cola INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_entidad TEXT,
        operacion TEXT,
        datos_json TEXT,
        local_uuid TEXT,
        estado TEXT,
        fecha_creacion TEXT,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Sesiones locales
    await db.execute('''
      CREATE TABLE sesiones_locales (
        id_sesion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        token_acceso TEXT,
        refresh_token TEXT,
        fecha_inicio TEXT,
        fecha_expiracion TEXT,
        dispositivo_id TEXT,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');

    // Errores de sincronización
    await db.execute('''
      CREATE TABLE errores_sync (
        id_error INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_error TEXT,
        mensaje_error TEXT,
        timestamp TEXT,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario)
      )
    ''');
  }

  Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migraciones incrementales
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN local_uuid TEXT');
      } catch (e) {
        // ignore si ya existe
      }
      try {
        await db.execute('ALTER TABLE usuarios ADD COLUMN remote_id INTEGER');
      } catch (e) {}

      try {
        await db.execute(
          'ALTER TABLE credenciales_biometricas ADD COLUMN local_uuid TEXT',
        );
      } catch (e) {}
      try {
        await db.execute(
          'ALTER TABLE credenciales_biometricas ADD COLUMN remote_id INTEGER',
        );
      } catch (e) {}

      try {
        await db.execute(
          'ALTER TABLE cola_sincronizacion ADD COLUMN local_uuid TEXT',
        );
      } catch (e) {}
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  // Cifrar datos sensibles antes de guardar
  static String encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(
      encryptionPassword.padRight(32).substring(0, 32),
    );
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  // Desencriptar datos
  static String decryptData(String encryptedText) {
    final key = encrypt.Key.fromUtf8(
      encryptionPassword.padRight(32).substring(0, 32),
    );
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final decrypted = encrypter.decrypt64(encryptedText);
    return decrypted;
  }
}
