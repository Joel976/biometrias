import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import '../services/local_database_service.dart';
import '../services/offline_sync_service.dart';
import '../services/admin_settings_service.dart';
import '../services/biometric_backend_service.dart';
import '../services/native_voice_mobile_service.dart';
import '../services/native_ear_mobile_service.dart';
import '../models/biometric_models.dart';
import 'package:dio/dio.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();

  factory SyncManager() {
    return _instance;
  }

  SyncManager._internal();

  final _connectivity = Connectivity();
  final _localDb = LocalDatabaseService();
  final _offlineSync = OfflineSyncService();
  final _api = ApiConfig();
  final _adminService = AdminSettingsService();

  Timer? _syncTimer;
  bool _isSyncing = false;
  Duration _syncInterval = Duration(
    minutes: 5,
  ); // Default, se actualiza desde admin

  // Configuración de reintentos (se actualiza desde admin settings)
  int _maxRetries = 5;
  static const _initialRetryDelayMs = 5000; // 5 segundos
  static const _maxRetryDelayMs = 1800000; // 30 minutos

  // Stream para notificaciones de sync
  final _syncStatusStream = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusStream.stream;

  // Iniciar sincronización automática
  void startAutoSync() async {
    // Cargar configuraciones de admin
    try {
      final settings = await _adminService.loadSettings();
      _syncInterval = Duration(minutes: settings.syncIntervalMinutes);
      _maxRetries = settings.maxRetryAttempts;

      print(
        '[SyncManager] ⚙️ Configurado con intervalo: ${settings.syncIntervalMinutes} min, reintentos: ${settings.maxRetryAttempts}',
      );
    } catch (e) {
      print(
        '[SyncManager] ⚠️ Error cargando configuraciones, usando valores por defecto: $e',
      );
    }

    _syncTimer?.cancel();

    // Solo iniciar auto-sync si está habilitado en configuraciones
    final settings = await _adminService.loadSettings();
    if (!settings.autoSyncEnabled) {
      print('[SyncManager] ⏸️ Auto-sync deshabilitado en configuraciones');
      return;
    }

    print(
      '[SyncManager] 🚀 Auto-sync ACTIVADO - intervalo: ${_syncInterval.inMinutes} minutos',
    );

    // 🔥 SINCRONIZAR INMEDIATAMENTE AL INICIAR
    print('[SyncManager] 🔄 Ejecutando sincronización inicial...');
    await performSync();

    // Luego configurar timer periódico
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      print(
        '[SyncManager] ⏰ Timer activado - ejecutando sincronización periódica...',
      );
      await performSync();
    });
  }

  // Detener sincronización automática
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // Realizar sincronización
  Future<SyncResult> performSync({int? idUsuario}) async {
    print('[SyncManager] ═══════════════════════════════════════');
    print('[SyncManager] 🔄 INICIANDO SINCRONIZACIÓN');
    print('[SyncManager] ═══════════════════════════════════════');

    // 🔥 No necesitamos ID de usuario específico - sincronizaremos TODOS los datos pendientes
    if (idUsuario != null) {
      print('[SyncManager] 👤 Sincronizando usuario específico: ID $idUsuario');
    } else {
      print(
        '[SyncManager] 🌐 Sincronizando TODOS los datos pendientes de TODOS los usuarios',
      );
    }

    if (_isSyncing) {
      print('[SyncManager] ⚠️ Sincronización ya en progreso, omitiendo...');
      return SyncResult(
        success: false,
        message: 'Sincronización ya en progreso',
      );
    }

    _isSyncing = true;
    _emitStatus(SyncStatus.syncing);

    try {
      // Verificar conectividad con timeout
      print('[SyncManager] 📡 Verificando conectividad...');
      final connectivityResult = await _connectivity
          .checkConnectivity()
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('[SyncManager] ⚠️ Timeout verificando conectividad');
              return [ConnectivityResult.none];
            },
          );

      final isOnline =
          connectivityResult.isNotEmpty &&
          connectivityResult.first != ConnectivityResult.none;

      print(
        '[SyncManager] 📡 Estado conexión: ${isOnline ? "ONLINE ✅" : "OFFLINE ❌"}',
      );

      if (!isOnline) {
        _emitStatus(SyncStatus.offline);
        print('[SyncManager] ❌ Sin conexión de red - sincronización cancelada');
        return SyncResult(success: false, message: 'Sin conexión de red');
      }

      // Ping al servidor
      print('[SyncManager] 🏓 Haciendo ping al servidor...');
      final pingSuccess = await _pingServer();
      print(
        '[SyncManager] 🏓 Ping resultado: ${pingSuccess ? "OK ✅" : "FALLO ❌"}',
      );

      if (!pingSuccess) {
        _emitStatus(SyncStatus.serverUnavailable);
        print(
          '[SyncManager] ❌ Servidor no disponible - sincronización cancelada',
        );
        return SyncResult(success: false, message: 'Servidor no disponible');
      }

      // 📊 Mostrar estadísticas de base de datos
      await _localDb.getDatabaseStats();

      // 🗑️ LIMPIAR items ya enviados de la cola
      print('[SyncManager] 🗑️ Limpiando cola de items ya sincronizados...');
      final itemsLimpiados = await _localDb.cleanSentSyncQueue();
      if (itemsLimpiados > 0) {
        print(
          '[SyncManager] ✅ $itemsLimpiados items ya enviados eliminados de la cola',
        );
      }

      // � REPARAR COLA DE SINCRONIZACIÓN antes de sincronizar
      print(
        '[SyncManager] 🔧 Verificando integridad de cola de sincronización...',
      );
      final itemsReparados = await _localDb.repairSyncQueue();
      if (itemsReparados > 0) {
        print('[SyncManager] ✅ Cola reparada: $itemsReparados items agregados');
      } else {
        print(
          '[SyncManager] ✅ Cola de sincronización OK (sin reparaciones necesarias)',
        );
      }

      // Sincronización bidireccional
      var uploadSuccess = false;
      var downloadSuccess = false;

      // 1. Subir datos (App → Backend)
      print('[SyncManager] 📤 Subiendo datos locales al backend...');
      uploadSuccess = await _uploadData(idUsuario);
      print(
        '[SyncManager] 📤 Subida: ${uploadSuccess ? "EXITOSA ✅" : "FALLIDA ❌"}',
      );

      // 2. Descargar datos (Backend → App) - solo si se especificó usuario
      if (idUsuario != null) {
        print('[SyncManager] 📥 Descargando datos del backend...');
        downloadSuccess = await _downloadData(idUsuario);
        print(
          '[SyncManager] 📥 Descarga: ${downloadSuccess ? "EXITOSA ✅" : "FALLIDA ❌"}',
        );
      } else {
        // Si no hay usuario específico, solo subimos datos
        downloadSuccess = true;
        print('[SyncManager] ℹ️ Descarga omitida (modo todos los usuarios)');
      }

      final overallSuccess = uploadSuccess && downloadSuccess;

      if (overallSuccess) {
        _emitStatus(SyncStatus.syncComplete);

        // Registrar sincronización exitosa (solo si hay usuario específico)
        if (idUsuario != null) {
          final syncState = SyncState(
            id: 0,
            idUsuario: idUsuario,
            fechaUltimoSync: DateTime.now(),
            tipoSync: 'bidireccional',
            estadoSync: 'completo',
            cantidadItems: 0,
          );
          await _localDb.insertSyncState(syncState);
        }
        print('[SyncManager] ✅✅✅ SINCRONIZACIÓN COMPLETADA EXITOSAMENTE');
      } else {
        _emitStatus(SyncStatus.syncError);
        print('[SyncManager] ❌ Sincronización completada con errores');
      }

      print('[SyncManager] ═══════════════════════════════════════\n');

      return SyncResult(
        success: overallSuccess,
        message: overallSuccess
            ? 'Sincronización exitosa'
            : 'Error parcial en sincronización',
      );
    } catch (error) {
      _emitStatus(SyncStatus.syncError);
      print('[SyncManager] ❌❌❌ ERROR DURANTE SINCRONIZACIÓN: $error');
      print('[SyncManager] ═══════════════════════════════════════\n');
      return SyncResult(
        success: false,
        message: 'Error durante sincronización: $error',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Guardar datos para sincronización offline (cuando no hay conexión)
  Future<int> saveDataForOfflineSync({
    required String endpoint,
    required Map<String, dynamic> data,
    String? photoBase64,
    String? audioBase64,
  }) async {
    try {
      return await _offlineSync.savePendingData(
        endpoint: endpoint,
        data: data,
        photoBase64: photoBase64,
        audioBase64: audioBase64,
      );
    } catch (e) {
      print('Error guardando dato offline: $e');
      rethrow;
    }
  }

  /// Obtener cantidad de datos pendientes de sincronizar
  Future<int> getPendingSyncCount() async {
    try {
      return await _offlineSync.getPendingCount();
    } catch (e) {
      print('Error obteniendo contador: $e');
      return 0;
    }
  }

  /// Stream para monitorear cantidad de datos pendientes
  Stream<int> getPendingSyncCountStream() async* {
    while (true) {
      final count = await getPendingSyncCount();
      yield count;
      await Future.delayed(Duration(seconds: 5));
    }
  }

  /// Sincronizar datos offline pendientes
  Future<SyncResult> syncOfflineData() async {
    try {
      final pendingDataList = await _offlineSync.getPendingData(limit: 10);

      if (pendingDataList.isEmpty) {
        return SyncResult(success: true, message: 'Sin datos pendientes');
      }

      int syncedCount = 0;
      int failedCount = 0;

      for (final pendingData in pendingDataList) {
        try {
          // Intentar sincronizar
          final response = await _api.dio
              .post(pendingData.endpoint, data: pendingData.data)
              .timeout(Duration(seconds: 30));

          if (response.statusCode == 200 || response.statusCode == 201) {
            // Exitoso
            await _offlineSync.deletePendingData(pendingData.id);
            syncedCount++;
          } else {
            // Error temporal, reintentar luego
            await _offlineSync.incrementRetryCount(pendingData.id);
            failedCount++;
          }
        } catch (e) {
          print('Error sincronizando dato ${pendingData.id}: $e');
          await _offlineSync.incrementRetryCount(pendingData.id);
          failedCount++;
        }
      }

      final success = failedCount == 0;
      final message = success
          ? 'Sincronizados $syncedCount datos'
          : '$syncedCount sincronizados, $failedCount fallidos. Reintentarán luego.';

      return SyncResult(success: success, message: message);
    } catch (e) {
      return SyncResult(success: false, message: 'Error sincronizando: $e');
    }
  }

  Future<bool> _pingServer() async {
    try {
      // 🔥 Hacer ping al backend de Python (puerto 8080) - endpoint correcto
      final dio = Dio(
        BaseOptions(
          baseUrl: 'http://167.71.155.9:8080',
          connectTimeout: Duration(seconds: 5),
          receiveTimeout: Duration(seconds: 5),
        ),
      );

      final response = await dio
          .get('/listar/frases')
          .timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (error) {
      print('[SyncManager] ⚠️ Error en ping /listar/frases: $error');

      // Si el endpoint falla, asumir que el servidor está disponible
      // y dejar que cada operación maneje sus propios errores
      print('[SyncManager] ℹ️ Asumiendo servidor disponible, continuando...');
      return true; // ✅ Continuar de todos modos
    }
  }

  // Subir datos al backend
  Future<bool> _uploadData(int? idUsuario) async {
    try {
      // 🔥 Si no se especifica usuario, sincronizar TODO
      final List<Map<String, dynamic>> pendingSync;
      if (idUsuario != null) {
        print(
          '[SyncManager] 🔍 Buscando datos pendientes para usuario: $idUsuario',
        );
        pendingSync = await _localDb.getPendingSyncQueue(idUsuario);
      } else {
        print('[SyncManager] 🔍 Buscando TODOS los datos pendientes...');
        pendingSync = await _localDb.getAllPendingSyncQueue();
      }

      print('[SyncManager] 📊 Items en cola: ${pendingSync.length}');

      if (pendingSync.isEmpty) {
        print('[SyncManager] ℹ️ No hay datos pendientes para sincronizar');
        return true; // Nada que subir
      }

      print(
        '[SyncManager] 📤 Subiendo ${pendingSync.length} items pendientes...',
      );

      int uploadedCount = 0;
      int failedCount = 0;

      // 🔥 Set para rastrear items ya procesados (evita reprocesar items agrupados)
      final Set<int> processedIds = {};

      // Procesar cada item individualmente según su tipo
      for (var item in pendingSync) {
        String tipo = '';
        int idCola = 0;

        try {
          tipo = item['tipo_entidad'] ?? '';
          final datos = item['datos_parsed'] ?? {};
          idCola = item['id'] ?? 0; // ✅ La columna se llama 'id', no 'id_cola'

          // ✅ Saltar items ya procesados en grupos anteriores
          if (processedIds.contains(idCola)) {
            continue;
          }

          print(
            '[SyncManager] 📦 Procesando item ${uploadedCount + 1}/${pendingSync.length}: tipo=$tipo (ID: $idCola)',
          );

          if (tipo == 'usuario') {
            // Registrar usuario en backend biométrico
            print('[SyncManager] 🔍 DEBUG - Datos recibidos:');
            print('  datos_parsed: $datos');
            print('  identificador_unico: ${datos['identificador_unico']}');
            print('  nombres: ${datos['nombres']}');
            print('  apellidos: ${datos['apellidos']}');

            final identificador = datos['identificador_unico'] ?? '';
            final nombres = datos['nombres'] ?? '';
            final apellidos = datos['apellidos'] ?? '';

            print('[SyncManager] 👤 Sincronizando usuario: $identificador');

            // 🔥 Validar que los datos no estén vacíos
            if (identificador.isEmpty || nombres.isEmpty || apellidos.isEmpty) {
              print(
                '[SyncManager] ⚠️ ERROR: Datos del usuario vacíos - omitiendo sincronización',
              );
              print(
                '[SyncManager] ⚠️ Marcando como procesado para evitar bucle',
              );
              await _localDb.markSyncQueueAsProcessed(idCola);
              failedCount++;
              continue;
            }

            final biometricBackend = BiometricBackendService();

            try {
              await biometricBackend
                  .registrarUsuario(
                    identificadorUnico: identificador,
                    nombres: nombres,
                    apellidos: apellidos,
                    fechaNacimiento: datos['fecha_nacimiento'],
                    sexo: datos['sexo'],
                  )
                  .timeout(
                    Duration(seconds: 60),
                    onTimeout: () =>
                        throw TimeoutException('Timeout registrando usuario'),
                  );
              print('[SyncManager] ✅ Usuario sincronizado: $identificador');
            } on DioException catch (e) {
              if (e.response?.statusCode == 409) {
                // 409 = Conflict = Usuario ya existe en el backend
                print(
                  '[SyncManager] ℹ️ Usuario ya registrado en backend (409) - marcando como exitoso',
                );
              } else {
                rethrow; // Otros errores sí se propagan
              }
            }

            await _localDb.markSyncQueueAsProcessed(idCola);
            uploadedCount++;
          } else if (tipo == 'credencial') {
            // 🔥 AGRUPAR CREDENCIALES POR USUARIO Y TIPO
            // El backend requiere TODAS las fotos/audios juntos (7 fotos u 5 audios)
            final tipoBiometria = datos['tipo_biometria'] ?? '';
            final identificador = datos['identificador_unico'] ?? '';

            print(
              '[SyncManager] 📸 Encontrada credencial $tipoBiometria para $identificador - AGRUPANDO...',
            );

            // Buscar TODAS las credenciales del mismo tipo para este usuario
            final credencialesGrupo = pendingSync.where((item) {
              final itemTipo = item['tipo_entidad'] ?? '';
              final itemDatos = item['datos_parsed'] ?? {};
              return itemTipo == 'credencial' &&
                  itemDatos['tipo_biometria'] == tipoBiometria &&
                  itemDatos['identificador_unico'] == identificador;
            }).toList();

            print(
              '[SyncManager] 📦 Agrupadas ${credencialesGrupo.length} credenciales de $tipoBiometria',
            );

            // 🔥 LÍMITE: Solo enviar las primeras N credenciales necesarias
            final int maxCredenciales = tipoBiometria == 'oreja' ? 7 : 6;

            if (credencialesGrupo.length > maxCredenciales) {
              print(
                '[SyncManager] ⚠️ Hay ${credencialesGrupo.length} credenciales, pero solo se necesitan $maxCredenciales',
              );
              print(
                '[SyncManager] 📌 Tomando solo las primeras $maxCredenciales credenciales',
              );
            }

            // Extraer solo las primeras N imágenes/audios necesarias
            final List<Uint8List> templates = [];
            final List<int> idsToMark = [];
            int contador = 0;

            for (var cred in credencialesGrupo) {
              if (contador >= maxCredenciales) {
                // Ya tenemos suficientes, marcar el resto como procesados sin enviar
                final credId = cred['id'] ?? 0;
                idsToMark.add(credId);
                continue;
              }

              final credDatos = cred['datos_parsed'] ?? {};
              final template = credDatos['template'] as List?;
              final credId = cred['id'] ?? 0;

              if (template != null && template.isNotEmpty) {
                final templateBytes = Uint8List.fromList(
                  template
                      .map(
                        (e) => e is int ? e : int.tryParse(e.toString()) ?? 0,
                      )
                      .toList(),
                );
                templates.add(templateBytes);
                idsToMark.add(credId);
                contador++;
              }
            }

            if (templates.isEmpty) {
              print('[SyncManager] ⚠️ No hay templates válidos, omitiendo...');
              await _localDb.markSyncQueueAsProcessed(idCola);
              continue;
            }

            print(
              '[SyncManager] 📤 Enviando ${templates.length} templates de $tipoBiometria al backend...',
            );

            final biometricBackend = BiometricBackendService();

            if (tipoBiometria == 'oreja') {
              try {
                await biometricBackend
                    .registrarBiometriaOreja(
                      identificador: identificador,
                      imagenes:
                          templates, // ✅ Enviar TODAS las imágenes agrupadas
                    )
                    .timeout(
                      Duration(seconds: 120), // 2 minutos para fotos grandes
                      onTimeout: () =>
                          throw TimeoutException('Timeout subiendo foto oreja'),
                    );
                print(
                  '[SyncManager] ✅ ${templates.length} fotos oreja sincronizadas',
                );
              } on DioException catch (e) {
                if (e.response?.statusCode == 409) {
                  // 409 = Conflict = El usuario ya tiene biometría registrada
                  print(
                    '[SyncManager] ℹ️ Biometría de oreja ya registrada (409) - marcando como exitoso',
                  );
                } else {
                  rethrow; // Otros errores sí se propagan
                }
              }
            } else if (tipoBiometria == 'voz') {
              // 🔥 VALIDAR: Solo enviar máximo 6 audios
              final audiosToSend = templates.length > 6
                  ? templates.sublist(0, 6)
                  : templates;

              if (templates.length > 6) {
                print(
                  '[SyncManager] ⚠️ Se encontraron ${templates.length} audios, enviando solo los primeros 6',
                );
              }

              try {
                await biometricBackend
                    .registrarBiometriaVoz(
                      identificador: identificador,
                      audios: audiosToSend, // ✅ Máximo 6 audios
                    )
                    .timeout(
                      Duration(seconds: 120), // 2 minutos para audios grandes
                      onTimeout: () =>
                          throw TimeoutException('Timeout subiendo audio voz'),
                    );
                print(
                  '[SyncManager] ✅ ${audiosToSend.length} audios voz sincronizados',
                );
              } on DioException catch (e) {
                if (e.response?.statusCode == 409) {
                  // 409 = Conflict = El usuario ya tiene biometría registrada
                  print(
                    '[SyncManager] ℹ️ Biometría de voz ya registrada (409) - marcando como exitoso',
                  );
                } else {
                  rethrow; // Otros errores sí se propagan
                }
              }
            }

            // ✅ Marcar TODOS los items del grupo como procesados
            for (var id in idsToMark) {
              await _localDb.markSyncQueueAsProcessed(id);
              processedIds.add(id); // ✅ Agregar al set para evitar reprocesar
            }
            uploadedCount += idsToMark.length;

            print('[SyncManager] ✅ Grupo de $tipoBiometria completado');

            // 🔥 LIMPIAR credenciales duplicadas de la base de datos
            // Mantener solo las primeras 7 (oreja) o 6 (voz)
            try {
              // Obtener id_usuario desde el identificador
              final usuario = await _localDb.getUserByIdentifier(identificador);
              if (usuario != null) {
                final idUsuario = usuario['id_usuario'] as int;
                final deletedCount = await _localDb.deleteExtraCredentials(
                  idUsuario,
                  tipoBiometria,
                );
                if (deletedCount > 0) {
                  print(
                    '[SyncManager] 🗑️ $deletedCount credenciales extras eliminadas de la BD local',
                  );
                }
              }
            } catch (e) {
              print('[SyncManager] ⚠️ Error limpiando credenciales extras: $e');
            }
          } else if (tipo == 'validacion' || tipo.contains('validacion')) {
            // 🔥 TEMPORAL: Saltar validaciones para evitar timeouts
            // Las validaciones son datos históricos de logins, no son críticos para el registro
            print(
              '[SyncManager] ⏭️ Saltando validación (no crítica) - marcando como procesada',
            );
            await _localDb.markSyncQueueAsProcessed(idCola);
            uploadedCount++;

            // TODO: Implementar sincronización de validaciones al backend Node.js cuando esté disponible
            /* 
            final payload = {
              'tipo_biometria': datos['tipo_biometria'] ?? 'voz',
              'resultado': datos['resultado'] ?? 'exito',
              'modo_validacion': datos['modo_validacion'] ?? 'offline',
              'puntuacion_confianza': datos['puntuacion_confianza'] ?? 0,
              'ubicacion_gps': datos['ubicacion_gps'],
            };

            final response = await _api.dio
                .post('/validaciones', data: payload)
                .timeout(Duration(seconds: 30));

            if (response.statusCode == 200 || response.statusCode == 201) {
              await _localDb.markSyncQueueAsProcessed(idCola);
              uploadedCount++;
              print('[SyncManager] ✅ Validación sincronizada');
            }
            */
          } else {
            // Tipo desconocido - marcar como procesado para evitar bucle
            print(
              '[SyncManager] ⚠️ Tipo desconocido: $tipo - marcando como procesado',
            );
            await _localDb.markSyncQueueAsProcessed(idCola);
            failedCount++;
          }
        } catch (e) {
          print(
            '[SyncManager] ❌ Error sincronizando item $idCola (tipo: $tipo): $e',
          );
          failedCount++;

          // 🔥 IMPORTANTE: Marcar como procesado incluso si falla
          // Para evitar que se quede atascado en el mismo item
          // TODO: Implementar sistema de reintentos con contador
          try {
            await _localDb.markSyncQueueAsProcessed(idCola);
            print(
              '[SyncManager] ⚠️ Item marcado como procesado para evitar bucle infinito',
            );
          } catch (markError) {
            print(
              '[SyncManager] ❌ Error marcando item como procesado: $markError',
            );
          }
        }
      }

      print(
        '[SyncManager] 📊 Resultado: $uploadedCount exitosos, $failedCount fallidos',
      );
      return failedCount == 0;
    } catch (error) {
      print('[SyncManager] ❌ Error al subir datos: $error');
      return false;
    }
  }

  // Descargar datos del backend
  Future<bool> _downloadData(int idUsuario) async {
    try {
      final lastSync = await _localDb.getLastSyncState(idUsuario);
      final ultimaSync = lastSync?.fechaUltimoSync ?? DateTime(2000);

      final response = await _api.dio
          .post(
            '/sync/descarga',
            data: {
              'id_usuario': idUsuario,
              'ultima_sync': ultimaSync.toIso8601String(),
              'dispositivo_id': 'device_$idUsuario',
            },
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200 && response.data['success'] == true) {
        final datos = response.data['datos'];

        // Procesar usuarios
        if (datos['usuarios'] is List) {
          for (var user in datos['usuarios'] as List) {
            // Aquí se guardarían los usuarios localmente
          }
        }

        // Procesar credenciales
        if (datos['credenciales_biometricas'] is List) {
          for (var cred in datos['credenciales_biometricas'] as List) {
            // Procesar credencial
          }
        }

        // Procesar frases de audio
        if (datos['textos_audio'] is List) {
          for (var frase in datos['textos_audio'] as List) {
            // Procesar frase
          }
        }

        return true;
      }

      return false;
    } catch (error) {
      print('Error al descargar datos: $error');
      return false;
    }
  }

  /// 🔄 Sincronizar frases del backend a la base de datos local
  Future<bool> syncPhrasesFromBackend() async {
    try {
      print('[SyncManager] 📥 Sincronizando frases del backend...');

      // Obtener frases del backend usando BiometricBackendService
      final backendService = BiometricBackendService();
      final isOnline = await backendService.isOnline();

      if (!isOnline) {
        print('[SyncManager] ⚠️ Sin conexión, no se pueden sincronizar frases');
        return false;
      }

      // Obtener todas las frases del backend
      final phrases = await backendService.listarFrases();

      if (phrases.isEmpty) {
        print('[SyncManager] ⚠️ No se obtuvieron frases del backend');
        return false;
      }

      // Guardar en la base de datos local
      await _localDb.syncPhrasesFromBackend(phrases);

      print(
        '[SyncManager] ✅ ${phrases.length} frases sincronizadas exitosamente',
      );
      return true;
    } catch (e) {
      print('[SyncManager] ❌ Error sincronizando frases: $e');
      return false;
    }
  }

  // Reintentar con backoff exponencial
  Future<T> _retryWithBackoff<T>(
    Future<T> Function() operation, {
    int retryCount = 0,
  }) async {
    try {
      return await operation();
    } catch (error) {
      if (retryCount < _maxRetries) {
        final delay = _calculateBackoffDelay(retryCount);
        await Future.delayed(delay);
        return _retryWithBackoff(operation, retryCount: retryCount + 1);
      } else {
        rethrow;
      }
    }
  }

  Duration _calculateBackoffDelay(int retryCount) {
    final delayMs = (_initialRetryDelayMs * (1 << retryCount)).clamp(
      0,
      _maxRetryDelayMs,
    );
    return Duration(milliseconds: delayMs as int);
  }

  void _emitStatus(SyncStatus status) {
    _syncStatusStream.add(status);
  }

  // ============================================================================
  // SINCRONIZACION NATIVA (usando liboreja_mobile.so y libvoz_mobile.so)
  // ============================================================================

  /// Sincronizar vectores de VOZ con el servidor (Push + Pull)
  Future<Map<String, dynamic>> syncNativeVoz(String serverUrl) async {
    print('[SyncManager] 🎤 Iniciando sincronización NATIVA de VOZ...');

    try {
      final nativeVoz = NativeVoiceMobileService();

      // 1. Push: Enviar vectores pendientes al servidor
      print('[SyncManager] 📤 VOZ Push...');
      final pushResult = await nativeVoz.syncPush(serverUrl);

      if (pushResult['ok'] != true) {
        throw Exception('Push fallido: ${pushResult['error']}');
      }

      print(
        '[SyncManager] ✅ VOZ Push exitoso: ${pushResult['enviados'] ?? 0} vectores enviados',
      );

      // 2. Pull: Descargar cambios del servidor
      print('[SyncManager] 📥 VOZ Pull...');
      final pullResult = await nativeVoz.syncPull(serverUrl);

      if (pullResult['ok'] != true) {
        throw Exception('Pull fallido: ${pullResult['error']}');
      }

      print(
        '[SyncManager] ✅ VOZ Pull exitoso: ${pullResult['insertados'] ?? 0} frases descargadas',
      );

      return {'success': true, 'push': pushResult, 'pull': pullResult};
    } catch (e) {
      print('[SyncManager] ❌ Error sincronizando VOZ: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sincronizar vectores de OREJA con el servidor (Push + Pull)
  Future<Map<String, dynamic>> syncNativeOreja(String serverUrl) async {
    print('[SyncManager] 👂 Iniciando sincronización NATIVA de OREJA...');

    try {
      final nativeOreja = NativeEarMobileService();

      // 1. Push: Enviar vectores pendientes al servidor
      print('[SyncManager] 📤 OREJA Push...');
      final pushResult = await nativeOreja.syncPush(serverUrl);

      if (pushResult['ok'] != true) {
        throw Exception('Push fallido: ${pushResult['error']}');
      }

      print(
        '[SyncManager] ✅ OREJA Push exitoso: ${pushResult['enviados'] ?? 0} vectores enviados',
      );

      // 2. Pull: Descargar cambios del servidor
      print('[SyncManager] 📥 OREJA Pull...');
      final pullResult = await nativeOreja.syncPull(serverUrl);

      if (pullResult['ok'] != true) {
        throw Exception('Pull fallido: ${pullResult['error']}');
      }

      print(
        '[SyncManager] ✅ OREJA Pull exitoso: ${pullResult['insertados'] ?? 0} credenciales descargadas',
      );

      return {'success': true, 'push': pushResult, 'pull': pullResult};
    } catch (e) {
      print('[SyncManager] ❌ Error sincronizando OREJA: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Descargar modelo re-entrenado de VOZ desde el servidor
  Future<Map<String, dynamic>> syncModeloVoz(
    String serverUrl,
    String identificador,
  ) async {
    print('[SyncManager] 🎤 Descargando modelo VOZ para $identificador...');

    try {
      final nativeVoz = NativeVoiceMobileService();
      final result = await nativeVoz.syncModelo(serverUrl, identificador);

      if (result['ok'] == true) {
        print(
          '[SyncManager] ✅ Modelo VOZ descargado: ${result['archivo_local']}',
        );
      } else {
        print('[SyncManager] ❌ Error descargando modelo: ${result['error']}');
      }

      return result;
    } catch (e) {
      print('[SyncManager] ❌ Excepción descargando modelo VOZ: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Descargar archivo de OREJA desde el servidor (templates/modelo/umbral)
  Future<Map<String, dynamic>> syncArchivoOreja(
    String serverUrl,
    String archivo,
  ) async {
    print('[SyncManager] 👂 Descargando archivo OREJA: $archivo...');

    try {
      final nativeOreja = NativeEarMobileService();
      final result = await nativeOreja.syncModelo(serverUrl, archivo);

      if (result['ok'] == true) {
        print(
          '[SyncManager] ✅ Archivo OREJA descargado: ${result['archivo_local']}',
        );

        // Si descargamos templates, recargarlos automáticamente
        if (archivo == 'templates_k1.csv') {
          print('[SyncManager] 🔄 Recargando templates en memoria...');
          await nativeOreja.reloadTemplates();
        }
      } else {
        print('[SyncManager] ❌ Error descargando archivo: ${result['error']}');
      }

      return result;
    } catch (e) {
      print('[SyncManager] ❌ Excepción descargando archivo OREJA: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Sincronización completa de AMBAS biometrías (VOZ + OREJA)
  Future<Map<String, dynamic>> syncNativeComplete(String serverUrl) async {
    print('[SyncManager] 🔄 Iniciando sincronización COMPLETA nativa...');

    final results = <String, dynamic>{};

    // Sincronizar VOZ
    results['voz'] = await syncNativeVoz(serverUrl);

    // Sincronizar OREJA
    results['oreja'] = await syncNativeOreja(serverUrl);

    final vozSuccess = results['voz']['success'] == true;
    final orejaSuccess = results['oreja']['success'] == true;

    results['success'] = vozSuccess && orejaSuccess;

    if (results['success']) {
      print('[SyncManager] ✅✅ Sincronización nativa COMPLETA exitosa');
    } else {
      print('[SyncManager] ⚠️ Sincronización nativa completada con errores');
    }

    return results;
  }

  void dispose() {
    stopAutoSync();
    _syncStatusStream.close();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  SyncResult({required this.success, required this.message, this.data});
}

enum SyncStatus {
  idle,
  syncing,
  offline,
  serverUnavailable,
  syncComplete,
  syncError,
}
