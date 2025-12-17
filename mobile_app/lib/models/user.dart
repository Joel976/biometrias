// Simple POJO classes to avoid Freezed generation issues in this workspace.
// These are straightforward data containers with JSON (de)serialization.

class User {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String identificadorUnico;
  final String estado;
  final String? correoElectronico;
  final String? numeroTelefonico;
  final String? fechaNacimiento;
  final String? sexo;

  User({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.identificadorUnico,
    required this.estado,
    this.correoElectronico,
    this.numeroTelefonico,
    this.fechaNacimiento,
    this.sexo,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    idUsuario: (json['idUsuario'] ?? json['id_usuario']) as int,
    nombres: json['nombres'] as String,
    apellidos: json['apellidos'] as String,
    identificadorUnico:
        (json['identificadorUnico'] ?? json['identificador_unico']) as String,
    estado: json['estado'] as String,
    correoElectronico: json['correoElectronico'] as String?,
    numeroTelefonico: json['numeroTelefonico'] as String?,
    fechaNacimiento: json['fechaNacimiento'] as String?,
    sexo: json['sexo'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'idUsuario': idUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'identificadorUnico': identificadorUnico,
    'estado': estado,
    'correoElectronico': correoElectronico,
    'numeroTelefonico': numeroTelefonico,
    'fechaNacimiento': fechaNacimiento,
    'sexo': sexo,
  };
}

class UsuarioLocal {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String identificadorUnico;
  final String estado;
  final DateTime fechaSincronizacion;

  UsuarioLocal({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.identificadorUnico,
    required this.estado,
    required this.fechaSincronizacion,
  });

  factory UsuarioLocal.fromJson(Map<String, dynamic> json) => UsuarioLocal(
    idUsuario: (json['idUsuario'] ?? json['id_usuario']) as int,
    nombres: json['nombres'] as String,
    apellidos: json['apellidos'] as String,
    identificadorUnico:
        (json['identificadorUnico'] ?? json['identificador_unico']) as String,
    estado: json['estado'] as String,
    fechaSincronizacion: json['fechaSincronizacion'] is String
        ? DateTime.parse(json['fechaSincronizacion'] as String)
        : (json['fechaSincronizacion'] as DateTime?) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'idUsuario': idUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'identificadorUnico': identificadorUnico,
    'estado': estado,
    'fechaSincronizacion': fechaSincronizacion.toIso8601String(),
  };
}
