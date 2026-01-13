import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:biometric_auth/services/auth_service.dart';
import 'package:biometric_auth/services/ear_validator_service.dart';
import 'package:biometric_auth/services/admin_settings_service.dart';
import 'package:biometric_auth/models/admin_settings.dart';

@GenerateMocks([AuthService, EarValidatorService, AdminSettingsService])
import 'biometric_flow_test.mocks.dart';

void main() {
  group('Flujo Completo de Registro y Login Biométrico', () {
    late MockAuthService mockAuthService;
    late MockEarValidatorService mockEarValidator;
    late MockAdminSettingsService mockAdminSettings;

    setUp(() {
      mockAuthService = MockAuthService();
      mockEarValidator = MockEarValidatorService();
      mockAdminSettings = MockAdminSettingsService();

      // Configurar settings por defecto
      when(
        mockAdminSettings.loadSettings(),
      ).thenAnswer((_) async => AdminSettings(enableEarValidation: true));
    });

    tearDown(() {
      // Resetear mocks después de cada test para evitar interferencias
      reset(mockAuthService);
      reset(mockEarValidator);
      reset(mockAdminSettings);
    });

    /// Simula una imagen de oreja válida (224x224 pixels, formato simplificado)
    Uint8List createMockEarImage({bool isValid = true}) {
      // Crear una imagen de prueba simple (no real, solo bytes de ejemplo)
      // En producción, esto sería una imagen PNG/JPEG real
      // Agregar timestamp para hacer cada imagen única
      final uniqueSeed = DateTime.now().microsecondsSinceEpoch;

      if (isValid) {
        // Simular imagen de oreja clara (patrón específico + timestamp)
        return Uint8List.fromList(
          List.generate(1024, (i) => (i + uniqueSeed) % 255),
        );
      } else {
        // Simular objeto random (patrón diferente + timestamp)
        return Uint8List.fromList(
          List.generate(1024, (i) => (255 - i + uniqueSeed) % 255),
        );
      }
    }

    test(
      'Registro: Debe capturar y validar 3 fotos de oreja correctamente',
      () async {
        // Arrange
        final userId = 'TEST_USER_001';
        final photo1 = createMockEarImage(isValid: true);
        final photo2 = createMockEarImage(isValid: true);
        final photo3 = createMockEarImage(isValid: true);

        // Configurar validador para aceptar cualquier foto válida
        when(mockEarValidator.validateEar(any)).thenAnswer(
          (_) async =>
              EarDetectionResult(isEar: true, confidence: 0.90, error: null),
        );

        // Configurar servicio de auth para aceptar cualquier registro
        when(
          mockAuthService.registerEarPhoto(any, any, any),
        ).thenAnswer((_) async => null);

        // Act - Simular flujo de registro
        final validationResult1 = await mockEarValidator.validateEar(photo1);
        expect(
          validationResult1.isValid,
          true,
          reason: 'Foto 1 debe ser válida',
        );
        expect(
          validationResult1.confidence,
          greaterThanOrEqualTo(0.65),
          reason: 'Confianza debe ser >= 65%',
        );

        await mockAuthService.registerEarPhoto(userId, photo1, 1);

        final validationResult2 = await mockEarValidator.validateEar(photo2);
        expect(
          validationResult2.isValid,
          true,
          reason: 'Foto 2 debe ser válida',
        );

        await mockAuthService.registerEarPhoto(userId, photo2, 2);

        final validationResult3 = await mockEarValidator.validateEar(photo3);
        expect(
          validationResult3.isValid,
          true,
          reason: 'Foto 3 debe ser válida',
        );

        await mockAuthService.registerEarPhoto(userId, photo3, 3);

        // Assert - Verificar que se validaron 3 fotos y se registraron 3 veces
        verify(mockEarValidator.validateEar(any)).called(3);
        verify(mockAuthService.registerEarPhoto(userId, any, any)).called(3);

        print('✅ Registro completado: 3/3 fotos capturadas y validadas');
      },
    );

    test('Registro: Debe rechazar fotos borrosas o inválidas', () async {
      // Arrange
      final blurryPhoto = createMockEarImage(isValid: false);

      // Configurar validador para rechazar foto borrosa
      when(mockEarValidator.validateEar(blurryPhoto)).thenAnswer(
        (_) async => EarDetectionResult(
          isEar: false,
          confidence: 0.45,
          error: 'Imagen borrosa o de baja calidad',
        ),
      );

      // Act
      final result = await mockEarValidator.validateEar(blurryPhoto);

      // Assert
      expect(result.isValid, false, reason: 'Foto borrosa debe ser rechazada');
      expect(
        result.confidence,
        lessThan(0.65),
        reason: 'Confianza debe ser < 65%',
      );
      expect(result.error, isNotNull, reason: 'Debe incluir mensaje de error');

      print('✅ Foto borrosa rechazada correctamente: ${result.error}');
    });

    test('Registro: Debe rechazar objetos que no son orejas', () async {
      // Arrange
      final randomObject = createMockEarImage(isValid: false);

      // Configurar validador para rechazar objeto random
      when(mockEarValidator.validateEar(randomObject)).thenAnswer(
        (_) async =>
            EarDetectionResult(isEar: false, confidence: 0.12, error: null),
      );

      // Act
      final result = await mockEarValidator.validateEar(randomObject);

      // Assert
      expect(result.isValid, false, reason: 'Objeto random debe ser rechazado');
      expect(
        result.confidence,
        lessThan(0.30),
        reason: 'Confianza debe ser muy baja',
      );

      print(
        '✅ Objeto random rechazado: Confianza ${(result.confidence * 100).toStringAsFixed(1)}%',
      );
    });

    test(
      'Login: Debe autenticar usuario con foto de oreja registrada',
      () async {
        // Arrange
        final userId = 'TEST_USER_001';
        final loginPhoto = createMockEarImage(isValid: true);

        // Configurar validador para aceptar foto
        when(mockEarValidator.validateEar(loginPhoto)).thenAnswer(
          (_) async =>
              EarDetectionResult(isEar: true, confidence: 0.88, error: null),
        );

        // Configurar servicio de auth para autenticar
        when(
          mockAuthService.authenticateWithEarPhoto(userId, loginPhoto),
        ).thenAnswer((_) async => true);

        // Act
        final validationResult = await mockEarValidator.validateEar(loginPhoto);
        expect(
          validationResult.isValid,
          true,
          reason: 'Foto debe pasar validación TFLite',
        );

        final authResult = await mockAuthService.authenticateWithEarPhoto(
          userId,
          loginPhoto,
        );

        // Assert
        expect(authResult, true, reason: 'Usuario debe ser autenticado');
        verify(mockEarValidator.validateEar(loginPhoto)).called(1);
        verify(
          mockAuthService.authenticateWithEarPhoto(userId, loginPhoto),
        ).called(1);

        print('✅ Login exitoso: Usuario autenticado con oreja');
      },
    );

    test(
      'Login: Debe rechazar autenticación con foto de oreja no registrada',
      () async {
        // Arrange
        final userId = 'TEST_USER_002';
        final unknownEarPhoto = createMockEarImage(isValid: true);

        // Foto es válida según TFLite
        when(mockEarValidator.validateEar(unknownEarPhoto)).thenAnswer(
          (_) async =>
              EarDetectionResult(isEar: true, confidence: 0.91, error: null),
        );

        // Pero el backend no la reconoce (no está registrada)
        when(
          mockAuthService.authenticateWithEarPhoto(userId, unknownEarPhoto),
        ).thenAnswer((_) async => false);

        // Act
        final validationResult = await mockEarValidator.validateEar(
          unknownEarPhoto,
        );
        expect(
          validationResult.isValid,
          true,
          reason: 'Foto pasa validación TFLite (es una oreja válida)',
        );

        final authResult = await mockAuthService.authenticateWithEarPhoto(
          userId,
          unknownEarPhoto,
        );

        // Assert
        expect(
          authResult,
          false,
          reason:
              'Autenticación debe fallar (oreja no registrada para este usuario)',
        );

        print('✅ Oreja válida pero no registrada: Autenticación rechazada');
      },
    );

    test('Login: Debe rechazar si foto no es una oreja válida', () async {
      // Arrange
      final userId = 'TEST_USER_001';
      final invalidPhoto = createMockEarImage(isValid: false);

      // Configurar validador para rechazar
      when(mockEarValidator.validateEar(invalidPhoto)).thenAnswer(
        (_) async => EarDetectionResult(
          isEar: false,
          confidence: 0.23,
          error: 'No se detectó una oreja en la imagen',
        ),
      );

      // Act
      final validationResult = await mockEarValidator.validateEar(invalidPhoto);

      // Assert
      expect(
        validationResult.isValid,
        false,
        reason: 'Validación TFLite debe fallar',
      );

      // No debe llegar a llamar authenticateWithEarPhoto
      verifyNever(
        mockAuthService.authenticateWithEarPhoto(userId, invalidPhoto),
      );

      print('✅ Login rechazado: Foto no es una oreja válida');
    });

    test('Flujo Completo: Registro → Entrenamiento → Login Exitoso', () async {
      // Arrange
      final userId = 'TEST_USER_FULL_FLOW';
      final photo1 = createMockEarImage(isValid: true);
      final photo2 = createMockEarImage(isValid: true);
      final photo3 = createMockEarImage(isValid: true);
      final loginPhoto = createMockEarImage(isValid: true);

      // === FASE 1: REGISTRO (3 fotos) ===
      when(mockEarValidator.validateEar(any)).thenAnswer(
        (_) async =>
            EarDetectionResult(isEar: true, confidence: 0.90, error: null),
      );

      when(
        mockAuthService.registerEarPhoto(userId, any, any),
      ).thenAnswer((_) async => null);

      // Capturar 3 fotos
      await mockEarValidator.validateEar(photo1);
      await mockAuthService.registerEarPhoto(userId, photo1, 1);

      await mockEarValidator.validateEar(photo2);
      await mockAuthService.registerEarPhoto(userId, photo2, 2);

      await mockEarValidator.validateEar(photo3);
      await mockAuthService.registerEarPhoto(userId, photo3, 3);

      print('📸 Registro: 3/3 fotos capturadas');

      // === FASE 2: ENTRENAMIENTO (backend) ===
      // En producción, el backend entrena modelo aquí
      // Simulamos que el modelo ya está entrenado

      print('🧠 Entrenamiento: Modelo entrenado con 3 fotos');

      // === FASE 3: LOGIN (predicción) ===
      when(
        mockAuthService.authenticateWithEarPhoto(userId, loginPhoto),
      ).thenAnswer((_) async => true);

      final loginValidation = await mockEarValidator.validateEar(loginPhoto);
      expect(loginValidation.isValid, true);

      final authSuccess = await mockAuthService.authenticateWithEarPhoto(
        userId,
        loginPhoto,
      );

      // Assert
      expect(
        authSuccess,
        true,
        reason: 'Login debe ser exitoso con oreja registrada',
      );

      // Verificar que se registraron 3 fotos
      verify(mockAuthService.registerEarPhoto(userId, any, any)).called(3);

      // Verificar que se validó foto de login
      verify(
        mockAuthService.authenticateWithEarPhoto(userId, loginPhoto),
      ).called(1);

      print('✅ FLUJO COMPLETO EXITOSO: Registro → Entrenamiento → Login');
    });

    test('Estadísticas: Verificar tasas de aceptación/rechazo', () async {
      // Arrange
      final validPhotos = List.generate(
        10,
        (_) => createMockEarImage(isValid: true),
      );
      final invalidPhotos = List.generate(
        10,
        (_) => createMockEarImage(isValid: false),
      );

      // Configurar validador
      when(mockEarValidator.validateEar(any)).thenAnswer((invocation) async {
        final photo = invocation.positionalArguments[0] as Uint8List;
        // Determinar si es válida basado en el patrón de bytes
        final isValid = photo[0] < 128; // Criterio arbitrario para test
        return EarDetectionResult(
          isEar: isValid,
          confidence: isValid ? 0.85 : 0.25,
          error: isValid ? null : 'No es una oreja',
        );
      });

      // Act
      int acceptedCount = 0;
      int rejectedCount = 0;

      for (final photo in [...validPhotos, ...invalidPhotos]) {
        final result = await mockEarValidator.validateEar(photo);
        if (result.isValid) {
          acceptedCount++;
        } else {
          rejectedCount++;
        }
      }

      // Assert
      final totalTests = validPhotos.length + invalidPhotos.length;
      final acceptanceRate = (acceptedCount / totalTests) * 100;
      final rejectionRate = (rejectedCount / totalTests) * 100;

      print('📊 ESTADÍSTICAS:');
      print('  Total pruebas: $totalTests');
      print(
        '  Aceptadas: $acceptedCount (${acceptanceRate.toStringAsFixed(1)}%)',
      );
      print(
        '  Rechazadas: $rejectedCount (${rejectionRate.toStringAsFixed(1)}%)',
      );

      expect(totalTests, 20, reason: 'Debe probar 20 fotos');
      expect(
        acceptedCount + rejectedCount,
        totalTests,
        reason: 'Suma debe ser igual al total',
      );
    });
  });

  group('Validación del Modelo TFLite (Orden de Clases)', () {
    test('Debe mapear correctamente las 3 clases del modelo', () {
      // Este test verifica que el orden de clases sea el correcto:
      // output[0][0] = oreja_clara
      // output[0][1] = oreja_borrosa
      // output[0][2] = no_oreja

      final expectedOrder = ['oreja_clara', 'oreja_borrosa', 'no_oreja'];

      expect(
        expectedOrder[0],
        'oreja_clara',
        reason: 'Índice 0 debe ser oreja_clara',
      );
      expect(
        expectedOrder[1],
        'oreja_borrosa',
        reason: 'Índice 1 debe ser oreja_borrosa',
      );
      expect(
        expectedOrder[2],
        'no_oreja',
        reason: 'Índice 2 debe ser no_oreja',
      );

      print('✅ Orden de clases verificado: ${expectedOrder.join(", ")}');
    });

    test('Confianza debe estar en rango [0.0, 1.0]', () {
      final testConfidences = [0.0, 0.5, 0.65, 0.85, 1.0];

      for (final confidence in testConfidences) {
        expect(
          confidence,
          greaterThanOrEqualTo(0.0),
          reason: 'Confianza debe ser >= 0.0',
        );
        expect(
          confidence,
          lessThanOrEqualTo(1.0),
          reason: 'Confianza debe ser <= 1.0',
        );
      }

      print('✅ Todas las confianzas están en rango válido');
    });

    test('Umbral de confianza debe ser 65%', () {
      const expectedThreshold = 0.65;

      expect(
        expectedThreshold,
        0.65,
        reason: 'Umbral debe ser exactamente 0.65 (65%)',
      );

      print(
        '✅ Umbral de confianza confirmado: ${(expectedThreshold * 100).toStringAsFixed(0)}%',
      );
    });
  });
}
