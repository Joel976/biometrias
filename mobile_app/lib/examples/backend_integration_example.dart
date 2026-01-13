import 'dart:typed_data';
import 'package:biometric_auth/services/backend_service.dart';
import 'package:biometric_auth/services/ml_pipeline_service.dart';
import 'package:biometric_auth/config/environment_config.dart';

/// Ejemplo completo de uso del sistema biométrico con backend PostgreSQL
class BiometricIntegrationExample {
  final BackendService _backend = BackendService();
  final MLPipelineService _mlPipeline = MLPipelineService();

  /// Configurar URL del backend cuando te la den
  void configurarBackendOficial(String url) {
    print('📡 Configurando backend oficial...');
    EnvironmentConfig.setProductionUrl(url);
    print('✅ Backend configurado: $url');
  }

  /// Verificar si el backend está disponible
  Future<bool> verificarConexion() async {
    print('🔍 Verificando conexión con backend...');

    final online = await _backend.isOnline();

    if (online) {
      print('✅ Backend disponible y funcionando');
    } else {
      print('❌ Backend no disponible - usando modo offline');
    }

    return online;
  }

  /// Flujo completo: Registro de usuario + biometría de oreja
  Future<void> registroCompletoOreja({
    required String nombres,
    required String apellidos,
    required String email,
    required List<Uint8List> fotosOreja, // 3 fotos
  }) async {
    print('\n╔═══════════════════════════════════════════╗');
    print('║   REGISTRO COMPLETO CON OREJA             ║');
    print('╚═══════════════════════════════════════════╝\n');

    try {
      // 1. REGISTRAR USUARIO
      print('👤 Paso 1/4: Registrando usuario...');
      final usuario = await _backend.registerUser(
        nombres: nombres,
        apellidos: apellidos,
        identificadorUnico: email,
      );

      final userId = usuario['id_usuario'] as int;
      print('   ✅ Usuario registrado - ID: $userId\n');

      // 2. VALIDAR QUE TENEMOS 3 FOTOS
      if (fotosOreja.length != 3) {
        throw Exception('Se requieren exactamente 3 fotos de oreja');
      }

      // 3. PREPROCESAR Y REGISTRAR CADA FOTO
      print('📸 Paso 2/4: Procesando fotos de oreja...');

      for (int i = 0; i < fotosOreja.length; i++) {
        final numeroFoto = i + 1;
        print('   📷 Procesando foto $numeroFoto/3...');

        // Preprocesar imagen
        final imagenProcesada = await _mlPipeline.preprocessEarImage(
          fotosOreja[i],
        );

        // Validar calidad
        final calidad = _mlPipeline.validateEarImageQuality(imagenProcesada);
        if (!calidad['is_valid']) {
          throw Exception('Foto $numeroFoto rechazada: ${calidad['issues']}');
        }

        print('      ✓ Brillo: ${calidad['brightness'].toStringAsFixed(1)}');
        print('      ✓ Contraste: ${calidad['contrast'].toStringAsFixed(1)}');
        print('      ✓ Nitidez: ${calidad['sharpness'].toStringAsFixed(1)}');

        // Enviar al backend para entrenamiento
        await _backend.registerEarPhoto(
          idUsuario: userId,
          imageBytes: imagenProcesada,
          photoNumber: numeroFoto,
        );

        print('   ✅ Foto $numeroFoto/3 registrada\n');
      }

      // 4. ENTRENAMIENTO COMPLETADO (en backend)
      print('🧠 Paso 3/4: Backend entrenando modelo...');
      print('   ⏳ Procesando características...');
      print('   ⏳ Entrenando clasificador...');
      await Future.delayed(Duration(seconds: 2)); // Simular espera
      print('   ✅ Modelo de oreja entrenado\n');

      // 5. CONFIRMACIÓN FINAL
      print('🎉 Paso 4/4: Registro completado exitosamente!');
      print('   Usuario: $nombres $apellidos');
      print('   ID: $userId');
      print('   Email: $email');
      print('   Biometría: Oreja (3 fotos registradas)\n');
    } catch (e) {
      print('❌ Error en registro: $e');
      rethrow;
    }
  }

  /// Flujo completo: Login con biometría de oreja
  Future<bool> loginConOreja({
    required int userId,
    required Uint8List fotoOreja,
  }) async {
    print('\n╔═══════════════════════════════════════════╗');
    print('║   LOGIN CON OREJA                         ║');
    print('╚═══════════════════════════════════════════╝\n');

    try {
      // 1. PREPROCESAR IMAGEN
      print('📸 Paso 1/3: Procesando imagen...');
      final imagenProcesada = await _mlPipeline.preprocessEarImage(fotoOreja);

      // Validar calidad
      final calidad = _mlPipeline.validateEarImageQuality(imagenProcesada);
      if (!calidad['is_valid']) {
        print('❌ Imagen rechazada: ${calidad['issues']}');
        return false;
      }

      print('   ✓ Imagen válida\n');

      // 2. VERIFICAR EN BACKEND
      print('🔐 Paso 2/3: Verificando identidad...');
      final resultado = await _backend.verifyEarPhoto(
        idUsuario: userId,
        imageBytes: imagenProcesada,
      );

      final verified = resultado['verified'] as bool;
      final confidence = resultado['confidence'] as double;

      print('   Confianza: ${(confidence * 100).toStringAsFixed(1)}%');
      print('   Umbral: 75%\n');

      // 3. RESULTADO
      if (verified && confidence >= 0.75) {
        print('✅ Paso 3/3: Autenticación EXITOSA');
        print('   🎉 Acceso concedido\n');
        return true;
      } else {
        print('❌ Paso 3/3: Autenticación FALLIDA');
        print('   🚫 Acceso denegado\n');
        return false;
      }
    } catch (e) {
      print('❌ Error en login: $e');
      return false;
    }
  }

  /// Flujo completo: Registro de biometría de voz
  Future<void> registroCompletoVoz({
    required int userId,
    required Uint8List audioBytes,
  }) async {
    print('\n╔═══════════════════════════════════════════╗');
    print('║   REGISTRO DE VOZ                         ║');
    print('╚═══════════════════════════════════════════╝\n');

    try {
      // 1. PREPROCESAR AUDIO
      print('🎤 Paso 1/3: Validando audio...');
      final audioProcesado = await _mlPipeline.preprocessVoiceAudio(audioBytes);

      // Validar calidad
      final calidad = _mlPipeline.validateVoiceAudioQuality(audioProcesado);
      if (!calidad['is_valid']) {
        throw Exception('Audio rechazado: ${calidad['issues']}');
      }

      print('   ✓ Formato: WAV');
      print('   ✓ Sample Rate: ${calidad['sample_rate']} Hz');
      print('   ✓ Canales: ${calidad['num_channels']} (mono)');
      print('   ✓ Duración: ${calidad['duration'].toStringAsFixed(1)}s\n');

      // 2. REGISTRAR EN BACKEND
      print('🧠 Paso 2/3: Entrenando modelo de voz...');
      await _backend.registerVoiceAudio(
        idUsuario: userId,
        audioBytes: audioProcesado,
      );

      print('   ⏳ Extrayendo características MFCC...');
      print('   ⏳ Creando firma vocal...');
      await Future.delayed(Duration(seconds: 2)); // Simular espera
      print('   ✅ Modelo de voz entrenado\n');

      // 3. CONFIRMACIÓN
      print('✅ Paso 3/3: Registro de voz completado!');
      print('   Usuario ID: $userId');
      print('   Audio procesado correctamente\n');
    } catch (e) {
      print('❌ Error en registro de voz: $e');
      rethrow;
    }
  }

  /// Flujo completo: Login con biometría de voz
  Future<bool> loginConVoz({
    required int userId,
    required Uint8List audioBytes,
  }) async {
    print('\n╔═══════════════════════════════════════════╗');
    print('║   LOGIN CON VOZ                           ║');
    print('╚═══════════════════════════════════════════╝\n');

    try {
      // 1. VALIDAR AUDIO
      print('🎤 Paso 1/3: Validando audio...');
      final audioProcesado = await _mlPipeline.preprocessVoiceAudio(audioBytes);

      final calidad = _mlPipeline.validateVoiceAudioQuality(audioProcesado);
      if (!calidad['is_valid']) {
        print('❌ Audio rechazado: ${calidad['issues']}');
        return false;
      }

      print('   ✓ Audio válido\n');

      // 2. VERIFICAR EN BACKEND
      print('🔐 Paso 2/3: Verificando voz...');
      final resultado = await _backend.verifyVoiceAudio(
        idUsuario: userId,
        audioBytes: audioProcesado,
      );

      final verified = resultado['verified'] as bool;
      final confidence = resultado['confidence'] as double;

      print('   Confianza: ${(confidence * 100).toStringAsFixed(1)}%');
      print('   Umbral: 75%\n');

      // 3. RESULTADO
      if (verified && confidence >= 0.75) {
        print('✅ Paso 3/3: Autenticación EXITOSA');
        print('   🎉 Acceso concedido\n');
        return true;
      } else {
        print('❌ Paso 3/3: Autenticación FALLIDA');
        print('   🚫 Acceso denegado\n');
        return false;
      }
    } catch (e) {
      print('❌ Error en login de voz: $e');
      return false;
    }
  }

  /// Mostrar configuración actual
  void mostrarConfiguracion() {
    EnvironmentConfig.printConfig();
  }

  /// Ejemplo completo de uso
  static Future<void> ejemploCompleto() async {
    final ejemplo = BiometricIntegrationExample();

    // 1. CONFIGURAR BACKEND
    print('⚙️  CONFIGURACIÓN INICIAL\n');
    ejemplo.configurarBackendOficial('https://backend-oficial.com/api');
    await Future.delayed(Duration(seconds: 1));

    // 2. VERIFICAR CONEXIÓN
    final online = await ejemplo.verificarConexion();
    if (!online) {
      print('⚠️  No hay conexión - abortando ejemplo\n');
      return;
    }

    // 3. SIMULAR DATOS
    final fotosOreja = [
      Uint8List(100), // Simuladas - en realidad serían imágenes reales
      Uint8List(100),
      Uint8List(100),
    ];
    final fotoLogin = Uint8List(100);
    final audioRegistro = Uint8List(1000);
    final audioLogin = Uint8List(1000);

    // 4. REGISTRO COMPLETO
    await ejemplo.registroCompletoOreja(
      nombres: 'Juan',
      apellidos: 'Pérez',
      email: 'juan.perez@example.com',
      fotosOreja: fotosOreja,
    );

    // 5. LOGIN CON OREJA
    final loginExitoso = await ejemplo.loginConOreja(
      userId: 123,
      fotoOreja: fotoLogin,
    );

    print(
      'Resultado final: ${loginExitoso ? "ACCESO CONCEDIDO" : "ACCESO DENEGADO"}',
    );
  }
}

// Para ejecutar el ejemplo:
// void main() async {
//   await BiometricIntegrationExample.ejemploCompleto();
// }
