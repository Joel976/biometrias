class CredencialBiometrica {
  final int idCredencial;
  final int idUsuario;
  final String tipo; // 'oreja', 'voz'
  final String dataBiometrica; // base64 encoded
  final String vectorCaracteristicas; // fingerprint/features
  final DateTime fechaRegistro;
  final String estado; // 'activo', 'inactivo'
  final int? numeroFoto; // Para oreja: 1, 2, o 3

  CredencialBiometrica({
    required this.idCredencial,
    required this.idUsuario,
    required this.tipo,
    required this.dataBiometrica,
    required this.vectorCaracteristicas,
    required this.fechaRegistro,
    required this.estado,
    this.numeroFoto,
  });

  factory CredencialBiometrica.fromJson(Map<String, dynamic> json) =>
      CredencialBiometrica(
        idCredencial: (json['idCredencial'] ?? json['id_credencial']) as int,
        idUsuario: (json['idUsuario'] ?? json['id_usuario']) as int,
        tipo: json['tipo'] as String,
        dataBiometrica: json['dataBiometrica'] ?? json['data_biometrica'] ?? '',
        vectorCaracteristicas:
            json['vectorCaracteristicas'] ??
            json['vector_caracteristicas'] ??
            '',
        fechaRegistro: json['fechaRegistro'] is String
            ? DateTime.parse(json['fechaRegistro'] as String)
            : (json['fechaRegistro'] as DateTime?) ?? DateTime.now(),
        estado: json['estado'] as String? ?? 'activo',
        numeroFoto: json['numeroFoto'] ?? json['numero_foto'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'idCredencial': idCredencial,
    'idUsuario': idUsuario,
    'tipo': tipo,
    'dataBiometrica': dataBiometrica,
    'vectorCaracteristicas': vectorCaracteristicas,
    'fechaRegistro': fechaRegistro.toIso8601String(),
    'estado': estado,
    'numeroFoto': numeroFoto,
  };
}
