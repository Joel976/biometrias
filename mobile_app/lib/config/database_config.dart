import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseConfig {
  static const String dbName = 'biometrics_local.db';
  static const int dbVersion =
      12; // v12: Agregar columna embedding a credenciales_biometricas para comparación offline

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
    // 📌 Tabla principal de usuarios (IDÉNTICA A POSTGRESQL + campos de completitud)
    await db.execute('''
      CREATE TABLE usuarios (
        id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
        nombres TEXT,
        apellidos TEXT,
        fecha_nacimiento TEXT,
        sexo TEXT,
        identificador_unico TEXT UNIQUE NOT NULL,
        estado TEXT DEFAULT 'activo',
        fecha_registro TEXT DEFAULT CURRENT_TIMESTAMP,
        datos_completos INTEGER DEFAULT 0,
        orejas_completas INTEGER DEFAULT 0,
        voz_completa INTEGER DEFAULT 0
      )
    ''');

    // 📌 Tabla para credenciales biométricas (CON TEMPLATE BLOB)
    await db.execute('''
      CREATE TABLE credenciales_biometricas (
        id_credencial INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER NOT NULL,
        tipo_biometria TEXT CHECK (tipo_biometria IN ('oreja', 'voz', 'audio')),
        template BLOB,
        validez_hasta TEXT,
        version_algoritmo TEXT DEFAULT '1.0',
        fecha_captura TEXT DEFAULT CURRENT_TIMESTAMP,
        estado TEXT DEFAULT 'activo',
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
      )
    ''');

    // 📌 Tabla de frases dinámicas (CON CONTADOR Y LÍMITE DE USOS)
    await db.execute('''
      CREATE TABLE textos_dinamicos_audio (
        id_texto INTEGER PRIMARY KEY AUTOINCREMENT,
        frase TEXT NOT NULL,
        estado_texto TEXT DEFAULT 'activo',
        contador_usos INTEGER DEFAULT 0,
        limite_usos INTEGER DEFAULT 100
      )
    ''');

    // 📌 Tabla de auditoría de validaciones biométricas (COMPLETA)
    await db.execute('''
      CREATE TABLE validaciones_biometricas (
        id_validacion INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_biometria TEXT,
        resultado TEXT,
        modo_validacion TEXT DEFAULT 'offline',
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
        ubicacion_gps TEXT,
        dispositivo_id TEXT,
        puntuacion_confianza REAL,
        duracion_validacion INTEGER,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE SET NULL
      )
    ''');

    // 📌 TABLAS ADICIONALES SOLO PARA SQLITE (gestión local)

    // Tabla de templates biométricos locales (almacena los datos de oreja/voz)
    await db.execute('''
      CREATE TABLE templates_biometricos (
        id_template INTEGER PRIMARY KEY AUTOINCREMENT,
        id_credencial INTEGER NOT NULL,
        datos_biometricos BLOB,
        metadatos TEXT,
        FOREIGN KEY(id_credencial) REFERENCES credenciales_biometricas(id_credencial) ON DELETE CASCADE
      )
    ''');

    // Tabla de sincronización (para rastrear qué se ha enviado al backend)
    await db.execute('''
      CREATE TABLE sync_status (
        id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
        tabla_origen TEXT NOT NULL,
        id_registro_local INTEGER NOT NULL,
        id_registro_remoto INTEGER,
        estado_sync TEXT DEFAULT 'pendiente',
        fecha_ultimo_intento TEXT,
        intentos INTEGER DEFAULT 0,
        error_mensaje TEXT
      )
    ''');

    // Cola de sincronización para offline-first
    await db.execute('''
      CREATE TABLE cola_sincronizacion (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER,
        tipo_entidad TEXT NOT NULL,
        operacion TEXT NOT NULL,
        datos_json TEXT,
        local_uuid TEXT UNIQUE,
        estado TEXT DEFAULT 'pendiente',
        fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
        intentos_sync INTEGER DEFAULT 0,
        ultimo_error TEXT,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
      )
    ''');

    // Tabla para rastrear estado de sincronización por usuario
    await db.execute('''
      CREATE TABLE sincronizaciones (
        id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
        id_usuario INTEGER NOT NULL,
        fecha_ultima_sync TEXT DEFAULT CURRENT_TIMESTAMP,
        sincronizado INTEGER DEFAULT 1,
        FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
      )
    ''');

    print('✅ Base de datos SQLite creada con esquema PostgreSQL');

    // 📌 Insertar frases predeterminadas si no existen
    await _seedDefaultPhrases(db);
  }

  /// Insertar frases de audio predeterminadas para autenticación de voz
  Future<void> _seedDefaultPhrases(Database db) async {
    // Verificar si ya hay frases
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM textos_dinamicos_audio'),
    );

    if (count == null || count == 0) {
      print('📝 Insertando frases predeterminadas...');

      final defaultPhrases = [
        'La biometria de voz es una tecnologia innovadora que protege tu identidad de manera unica y segura',
        'Tu voz es tan unica como tu huella digital y representa la mejor forma de autenticacion personal',
        'Cada vez que hablas, tu voz crea un patron biometrico imposible de replicar por otra persona',
        'La seguridad de tus datos personales comienza con la autenticacion biometrica basada en tu voz natural',
        'Proteger tu identidad digital nunca fue tan facil gracias a la tecnologia de reconocimiento de voz avanzada',
        'La biometria vocal analiza caracteristicas unicas de tu voz que son imposibles de falsificar completamente',
        'Tu voz contiene miles de caracteristicas acusticas que te identifican de forma precisa y confiable',
        'El futuro de la seguridad digital esta en la autenticacion multimodal que incluye tu voz personal',
        'Cada palabra que pronuncias genera un patron espectral unico que funciona como tu firma digital personal',
        'La tecnologia de reconocimiento de voz hace que tus conversaciones sean la llave de tu seguridad digital',
        'Confiar en tu voz para autenticarte es confiar en la tecnologia mas avanzada de seguridad biometrica actual',
        'Los sistemas biometricos de voz analizan frecuencias y resonancias que son exclusivas de cada ser humano',
        'Tu voz es la contrasena mas segura porque combina aspectos fisicos y comportamentales unicos de tu persona',
        'La autenticacion por voz elimina la necesidad de recordar contrasenas complejas y dificiles de memorizar siempre',
        'Cada tono y modulacion de tu voz cuenta una historia unica que solo tu puedes narrar autentica',
        'La biometria vocal representa un avance tecnologico que revoluciona la forma en que protegemos nuestra identidad digital',
        'Tu voz es un instrumento biometrico natural que te seguira siempre sin necesidad de dispositivos adicionales externos',
        'Los algoritmos de procesamiento de voz extraen caracteristicas que hacen tu perfil vocal completamente irrepetible y seguro',
        'La seguridad biometrica basada en voz ofrece comodidad y proteccion sin comprometer la privacidad de los usuarios',
        'Cada registro de tu voz fortalece el modelo biometrico que garantiza una autenticacion mas precisa y confiable',
      ];

      for (int i = 0; i < defaultPhrases.length; i++) {
        await db.insert('textos_dinamicos_audio', {
          'frase': defaultPhrases[i],
          'estado_texto': 'activo',
          'contador_usos': 0,
          'limite_usos': 150,
        });
      }

      print('✅ ${defaultPhrases.length} frases predeterminadas insertadas');
    } else {
      print('✓ Frases de audio ya existen ($count frases)');
    }
  }

  Future<void> _upgradeTables(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('🔄 Migrando base de datos de v$oldVersion a v$newVersion');

    if (oldVersion < 4) {
      // Recrear todas las tablas con el nuevo esquema
      await db.execute('DROP TABLE IF EXISTS cola_sincronizacion');
      await db.execute('DROP TABLE IF EXISTS sincronizaciones');
      await db.execute('DROP TABLE IF EXISTS sesiones_locales');
      await db.execute('DROP TABLE IF EXISTS errores_sync');
      await db.execute('DROP TABLE IF EXISTS templates_biometricos');
      await db.execute('DROP TABLE IF EXISTS sync_status');
      await db.execute('DROP TABLE IF EXISTS validaciones_biometricas');
      await db.execute('DROP TABLE IF EXISTS textos_dinamicos_audio');
      await db.execute('DROP TABLE IF EXISTS credenciales_biometricas');
      await db.execute('DROP TABLE IF EXISTS usuarios');

      // Recrear con nuevo esquema
      await _createTables(db, newVersion);
      print('✅ Migración completada a esquema PostgreSQL v4');
    }

    if (oldVersion < 5) {
      // Agregar campos de completitud a usuarios existentes
      // Verificar primero si las columnas ya existen
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(usuarios)');
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('datos_completos')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN datos_completos INTEGER DEFAULT 0',
          );
          print('✅ Campo datos_completos agregado');
        }

        if (!columnNames.contains('orejas_completas')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN orejas_completas INTEGER DEFAULT 0',
          );
          print('✅ Campo orejas_completas agregado');
        }

        if (!columnNames.contains('voz_completa')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN voz_completa INTEGER DEFAULT 0',
          );
          print('✅ Campo voz_completa agregado');
        }

        print('✅ Migración completada a v5: Campos de completitud verificados');
      } catch (e) {
        print('⚠️ Error en migración v5: $e');
        // Si falla, intentar recrear la tabla
        print('🔄 Recreando tabla usuarios con nuevos campos...');

        // Respaldar datos existentes
        final backupData = await db.query('usuarios');

        // Eliminar y recrear tabla
        await db.execute('DROP TABLE IF EXISTS usuarios');
        await db.execute('''
          CREATE TABLE usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            nombres TEXT,
            apellidos TEXT,
            fecha_nacimiento TEXT,
            sexo TEXT,
            identificador_unico TEXT UNIQUE NOT NULL,
            estado TEXT DEFAULT 'activo',
            fecha_registro TEXT DEFAULT CURRENT_TIMESTAMP,
            datos_completos INTEGER DEFAULT 0,
            orejas_completas INTEGER DEFAULT 0,
            voz_completa INTEGER DEFAULT 0
          )
        ''');

        // Restaurar datos
        for (final row in backupData) {
          await db.insert('usuarios', {
            ...row,
            'datos_completos': 0,
            'orejas_completas': 0,
            'voz_completa': 0,
          });
        }

        print('✅ Tabla usuarios recreada con campos de completitud');
      }
    }

    // v6: Asegurar que todos los campos existen (idempotente)
    if (oldVersion < 6) {
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(usuarios)');
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('datos_completos')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN datos_completos INTEGER DEFAULT 0',
          );
        }
        if (!columnNames.contains('orejas_completas')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN orejas_completas INTEGER DEFAULT 0',
          );
        }
        if (!columnNames.contains('voz_completa')) {
          await db.execute(
            'ALTER TABLE usuarios ADD COLUMN voz_completa INTEGER DEFAULT 0',
          );
        }
        print('✅ Migración v6: Campos de completitud verificados');
      } catch (e) {
        print(
          '⚠️ Error en migración v6, pero se puede ignorar si ya existen: $e',
        );
      }
    }

    // v7: Agregar columnas faltantes en validaciones_biometricas
    if (oldVersion < 7) {
      try {
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info(validaciones_biometricas)',
        );
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('modo_validacion')) {
          await db.execute(
            'ALTER TABLE validaciones_biometricas ADD COLUMN modo_validacion TEXT DEFAULT \'offline\'',
          );
          print('✅ Columna modo_validacion agregada');
        }
        if (!columnNames.contains('ubicacion_gps')) {
          await db.execute(
            'ALTER TABLE validaciones_biometricas ADD COLUMN ubicacion_gps TEXT',
          );
          print('✅ Columna ubicacion_gps agregada');
        }
        if (!columnNames.contains('dispositivo_id')) {
          await db.execute(
            'ALTER TABLE validaciones_biometricas ADD COLUMN dispositivo_id TEXT',
          );
          print('✅ Columna dispositivo_id agregada');
        }
        if (!columnNames.contains('puntuacion_confianza')) {
          await db.execute(
            'ALTER TABLE validaciones_biometricas ADD COLUMN puntuacion_confianza REAL',
          );
          print('✅ Columna puntuacion_confianza agregada');
        }
        if (!columnNames.contains('duracion_validacion')) {
          await db.execute(
            'ALTER TABLE validaciones_biometricas ADD COLUMN duracion_validacion INTEGER',
          );
          print('✅ Columna duracion_validacion agregada');
        }
        print('✅ Migración v7: Tabla validaciones_biometricas actualizada');
      } catch (e) {
        print(
          '⚠️ Error en migración v7, pero se puede ignorar si ya existen: $e',
        );
      }
    }

    // v8: Agregar columnas de template a credenciales_biometricas
    if (oldVersion < 8) {
      try {
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info(credenciales_biometricas)',
        );
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('template')) {
          await db.execute(
            'ALTER TABLE credenciales_biometricas ADD COLUMN template BLOB',
          );
          print('✅ Columna template agregada a credenciales_biometricas');
        }
        if (!columnNames.contains('validez_hasta')) {
          await db.execute(
            'ALTER TABLE credenciales_biometricas ADD COLUMN validez_hasta TEXT',
          );
          print('✅ Columna validez_hasta agregada a credenciales_biometricas');
        }
        if (!columnNames.contains('version_algoritmo')) {
          await db.execute(
            'ALTER TABLE credenciales_biometricas ADD COLUMN version_algoritmo TEXT DEFAULT \'1.0\'',
          );
          print(
            '✅ Columna version_algoritmo agregada a credenciales_biometricas',
          );
        }
        print(
          '✅ Migración v8: Tabla credenciales_biometricas actualizada con columnas de template',
        );
      } catch (e) {
        print(
          '⚠️ Error en migración v8, pero se puede ignorar si ya existen: $e',
        );
      }
    }

    // v9: Agregar tabla cola_sincronizacion
    if (oldVersion < 9) {
      try {
        // Verificar si la tabla ya existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='cola_sincronizacion'",
        );

        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE cola_sincronizacion (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_usuario INTEGER,
              tipo_entidad TEXT NOT NULL,
              operacion TEXT NOT NULL,
              datos_json TEXT,
              local_uuid TEXT UNIQUE,
              estado TEXT DEFAULT 'pendiente',
              fecha_creacion TEXT DEFAULT CURRENT_TIMESTAMP,
              intentos_sync INTEGER DEFAULT 0,
              ultimo_error TEXT,
              FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
            )
          ''');
          print('✅ Tabla cola_sincronizacion creada');
        }
        print('✅ Migración v9: Cola de sincronización verificada');
      } catch (e) {
        print(
          '⚠️ Error en migración v9, pero se puede ignorar si ya existe: $e',
        );
      }
    }

    // v10: Agregar columnas contador_usos y limite_usos a textos_dinamicos_audio
    if (oldVersion < 10) {
      try {
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info(textos_dinamicos_audio)',
        );
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('contador_usos')) {
          await db.execute(
            'ALTER TABLE textos_dinamicos_audio ADD COLUMN contador_usos INTEGER DEFAULT 0',
          );
          print('✅ Columna contador_usos agregada a textos_dinamicos_audio');
        }
        if (!columnNames.contains('limite_usos')) {
          await db.execute(
            'ALTER TABLE textos_dinamicos_audio ADD COLUMN limite_usos INTEGER DEFAULT 100',
          );
          print('✅ Columna limite_usos agregada a textos_dinamicos_audio');
        }
        print(
          '✅ Migración v10: Tabla textos_dinamicos_audio actualizada con gestión de usos',
        );
      } catch (e) {
        print(
          '⚠️ Error en migración v10, pero se puede ignorar si ya existen: $e',
        );
      }
    }

    // v11: Agregar tabla sincronizaciones
    if (oldVersion < 11) {
      try {
        // Verificar si la tabla ya existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='sincronizaciones'",
        );

        if (tables.isEmpty) {
          await db.execute('''
            CREATE TABLE sincronizaciones (
              id_sync INTEGER PRIMARY KEY AUTOINCREMENT,
              id_usuario INTEGER NOT NULL,
              fecha_ultima_sync TEXT DEFAULT CURRENT_TIMESTAMP,
              sincronizado INTEGER DEFAULT 1,
              FOREIGN KEY(id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
            )
          ''');
          print('✅ Tabla sincronizaciones creada');
        }
        print('✅ Migración v11: Tabla sincronizaciones verificada');
      } catch (e) {
        print(
          '⚠️ Error en migración v11, pero se puede ignorar si ya existe: $e',
        );
      }
    }

    // v12: Agregar columna embedding a credenciales_biometricas
    if (oldVersion < 12) {
      try {
        final tableInfo = await db.rawQuery(
          'PRAGMA table_info(credenciales_biometricas)',
        );
        final columnNames = tableInfo
            .map((col) => col['name'] as String)
            .toList();

        if (!columnNames.contains('embedding')) {
          await db.execute(
            'ALTER TABLE credenciales_biometricas ADD COLUMN embedding TEXT',
          );
          print('✅ Columna embedding agregada a credenciales_biometricas');
        }
        print(
          '✅ Migración v12: Embeddings del backend disponibles para comparación offline',
        );
      } catch (e) {
        print(
          '⚠️ Error en migración v12, pero se puede ignorar si ya existe: $e',
        );
      }
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  /// Resetear base de datos completamente (solo para desarrollo)
  Future<void> resetDatabase() async {
    final String path = join(await getDatabasesPath(), dbName);
    await deleteDatabase(path);
    _database = null;
    print('🗑️ Base de datos eliminada y reseteada');
  }
}
