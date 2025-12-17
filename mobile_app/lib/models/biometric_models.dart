class BiometricCredential {
  final int id;
  final int idUsuario;
  final String tipoBiometria; // 'audio', 'oreja', 'palma'
  final List<int> template; // BLOB
  final DateTime? validezHasta;
  final String versionAlgoritmo;
  final double? calidadCaptura;

  BiometricCredential({
    required this.id,
    required this.idUsuario,
    required this.tipoBiometria,
    required this.template,
    this.validezHasta,
    required this.versionAlgoritmo,
    this.calidadCaptura,
  });

  // Convertir desde Map (BD)
  factory BiometricCredential.fromMap(Map<String, dynamic> map) {
    return BiometricCredential(
      id: map['id_credencial'] as int,
      idUsuario: map['id_usuario'] as int,
      tipoBiometria: map['tipo_biometria'] as String,
      template: (map['template'] as List).cast<int>(),
      validezHasta: map['validez_hasta'] != null
          ? DateTime.parse(map['validez_hasta'] as String)
          : null,
      versionAlgoritmo: map['version_algoritmo'] as String,
      calidadCaptura: map['calidad_captura'] != null
          ? (map['calidad_captura'] as num).toDouble()
          : null,
    );
  }

  // Convertir a Map (BD)
  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'tipo_biometria': tipoBiometria,
      'template': template,
      'validez_hasta': validezHasta?.toIso8601String(),
      'version_algoritmo': versionAlgoritmo,
      // Nota: calidad_captura no existe en schema SQLite local
    };
  }

  // Verificar si está vigente
  bool get isVigente {
    if (validezHasta == null) return true;
    return validezHasta!.isAfter(DateTime.now());
  }
}

class AudioPhrase {
  final int id;
  final int idUsuario;
  final String frase;
  final String estadoTexto; // 'activo', 'usado', 'expirado'
  final DateTime fechaAsignacion;

  AudioPhrase({
    required this.id,
    required this.idUsuario,
    required this.frase,
    required this.estadoTexto,
    required this.fechaAsignacion,
  });

  factory AudioPhrase.fromMap(Map<String, dynamic> map) {
    return AudioPhrase(
      id: map['id_texto'] as int,
      idUsuario: map['id_usuario'] as int,
      frase: map['frase'] as String,
      estadoTexto: map['estado_texto'] as String,
      fechaAsignacion: DateTime.parse(map['fecha_asignacion'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'frase': frase,
      'estado_texto': estadoTexto,
    };
  }

  bool get isActive => estadoTexto == 'activo';
}

class BiometricValidation {
  final int id;
  final int idUsuario;
  final String tipoBiometria;
  final String resultado; // 'exito', 'fallo'
  final String modoValidacion; // 'online', 'offline'
  final DateTime timestamp;
  final String? ubicacionGps;
  final String? dispositivoId;
  final double? puntuacionConfianza;
  final int? duracionValidacion; // en ms

  BiometricValidation({
    required this.id,
    required this.idUsuario,
    required this.tipoBiometria,
    required this.resultado,
    required this.modoValidacion,
    required this.timestamp,
    this.ubicacionGps,
    this.dispositivoId,
    this.puntuacionConfianza,
    this.duracionValidacion,
  });

  factory BiometricValidation.fromMap(Map<String, dynamic> map) {
    return BiometricValidation(
      id: map['id_validacion'] as int,
      idUsuario: map['id_usuario'] as int,
      tipoBiometria: map['tipo_biometria'] as String,
      resultado: map['resultado'] as String,
      modoValidacion: map['modo_validacion'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      ubicacionGps: map['ubicacion_gps'] as String?,
      dispositivoId: map['dispositivo_id'] as String?,
      puntuacionConfianza: map['puntuacion_confianza'] != null
          ? (map['puntuacion_confianza'] as num).toDouble()
          : null,
      duracionValidacion: map['duracion_validacion'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'tipo_biometria': tipoBiometria,
      'resultado': resultado,
      'modo_validacion': modoValidacion,
      'timestamp': timestamp.toIso8601String(),
      'ubicacion_gps': ubicacionGps,
      'puntuacion_confianza': puntuacionConfianza,
      // Nota: dispositivo_id y duracion_validacion no existen en schema SQLite local
    };
  }

  bool get isSuccessful => resultado == 'exito';
}

class SyncState {
  final int id;
  final int idUsuario;
  final DateTime fechaUltimoSync;
  final String tipoSync; // 'envio', 'recepcion', 'bidireccional'
  final String estadoSync; // 'completo', 'pendiente', 'error'
  final int cantidadItems;
  final String? codigoError;

  SyncState({
    required this.id,
    required this.idUsuario,
    required this.fechaUltimoSync,
    required this.tipoSync,
    required this.estadoSync,
    required this.cantidadItems,
    this.codigoError,
  });

  factory SyncState.fromMap(Map<String, dynamic> map) {
    return SyncState(
      id: map['id_sync'] as int,
      idUsuario: map['id_usuario'] as int,
      fechaUltimoSync: DateTime.parse(map['fecha_ultima_sync'] as String),
      tipoSync: map['tipo_sync'] as String,
      estadoSync: map['estado_sync'] as String,
      cantidadItems: map['cantidad_items'] as int? ?? 0,
      codigoError: map['codigo_error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'fecha_ultima_sync': fechaUltimoSync.toIso8601String(),
      'tipo_sync': tipoSync,
      'estado_sync': estadoSync,
      'cantidad_items': cantidadItems,
      'codigo_error': codigoError,
    };
  }

  bool get isComplete => estadoSync == 'completo';
  bool get hasFailed => estadoSync == 'error';
}
