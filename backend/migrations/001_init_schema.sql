-- =====================================================
-- MIGRACIONES PARA BASE DE DATOS POSTGRESQL
-- Sistema de Autenticación Biométrica
-- =====================================================

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    fecha_nacimiento DATE,
    sexo VARCHAR(10),
    identificador_unico VARCHAR(100) UNIQUE NOT NULL,
    estado VARCHAR(20) DEFAULT 'activo',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP,
    correo_electronico VARCHAR(100),
    numero_telefonico VARCHAR(20)
);

-- Tabla de credenciales biométricas
CREATE TABLE IF NOT EXISTS credenciales_biometricas (
    id_credencial SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    tipo_biometria VARCHAR(20) NOT NULL, -- 'audio', 'oreja', 'palma'
    template BYTEA NOT NULL,
    fecha_captura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    validez_desde DATE,
    validez_hasta DATE,
    version_algoritmo VARCHAR(50),
    estado VARCHAR(20) DEFAULT 'activo',
    hash_integridad VARCHAR(256),
    calidad_captura FLOAT,
    INDEX idx_usuario_biometria (id_usuario, tipo_biometria)
);

-- Tabla de frases dinámicas para audio
CREATE TABLE IF NOT EXISTS textos_dinamicos_audio (
    id_texto SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    frase TEXT NOT NULL,
    fecha_asignacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado_texto VARCHAR(20) DEFAULT 'activo', -- 'activo', 'usado', 'expirado'
    intentos_fallidos INTEGER DEFAULT 0,
    intentos_maximos INTEGER DEFAULT 3
);

-- Tabla de validaciones biométricas
CREATE TABLE IF NOT EXISTS validaciones_biometricas (
    id_validacion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    tipo_biometria VARCHAR(20) NOT NULL,
    resultado VARCHAR(10) NOT NULL, -- 'exito', 'fallo'
    modo_validacion VARCHAR(10) DEFAULT 'online', -- 'online', 'offline'
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ubicacion_gps VARCHAR(100),
    dispositivo_id VARCHAR(100),
    puntuacion_confianza FLOAT,
    duracion_validacion INTEGER, -- en milisegundos
    error_codigo VARCHAR(50),
    INDEX idx_usuario_resultado (id_usuario, resultado)
);

-- Tabla de dispositivos
CREATE TABLE IF NOT EXISTS dispositivos_app (
    dispositivo_id VARCHAR(100) PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    modelo VARCHAR(100),
    version_app VARCHAR(20),
    sistema_operativo VARCHAR(50),
    fecha_activacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ultimo_sync TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'activo'
);

-- Tabla de sincronización
CREATE TABLE IF NOT EXISTS sincronizaciones (
    id_sync SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    dispositivo_id VARCHAR(100),
    fecha_ultima_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_sync VARCHAR(20), -- 'envio', 'recepcion', 'bidireccional'
    estado_sync VARCHAR(20) DEFAULT 'pendiente', -- 'completo', 'pendiente', 'error'
    cantidad_items INTEGER,
    tamano_transferencia INTEGER,
    tiempo_duracion INTEGER,
    codigo_error VARCHAR(50),
    INDEX idx_usuario_fecha (id_usuario, fecha_ultima_sync)
);

-- Tabla de cola de sincronización (elementos pendientes)
CREATE TABLE IF NOT EXISTS cola_sincronizacion (
    id_cola SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    tipo_entidad VARCHAR(50), -- 'validacion', 'template', 'frase'
    id_entidad INTEGER,
    operacion VARCHAR(20), -- 'INSERT', 'UPDATE', 'DELETE'
    datos_json JSONB,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'enviado', 'error'
    intentos_envio INTEGER DEFAULT 0,
    proximo_reintento TIMESTAMP,
    INDEX idx_usuario_estado (id_usuario, estado)
);

-- Tabla de errores de sincronización
CREATE TABLE IF NOT EXISTS errores_sync (
    id_error SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    dispositivo_id VARCHAR(100),
    tipo_error VARCHAR(50),
    mensaje_error TEXT,
    codigo_http INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resuelto BOOLEAN DEFAULT FALSE,
    INDEX idx_usuario_timestamp (id_usuario, timestamp)
);

-- Tabla de sesiones
CREATE TABLE IF NOT EXISTS sesiones (
    id_sesion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    dispositivo_id VARCHAR(100),
    token_acceso VARCHAR(500),
    refresh_token VARCHAR(500),
    tipo_autenticacion VARCHAR(20), -- 'biometrica', 'basica'
    fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP,
    fecha_ultimo_uso TIMESTAMP,
    ip_origen VARCHAR(50),
    user_agent TEXT,
    estado VARCHAR(20) DEFAULT 'activa',
    INDEX idx_usuario_dispositivo (id_usuario, dispositivo_id)
);

-- Tabla de logs de auditoría
CREATE TABLE IF NOT EXISTS logs_auditoria (
    id_log SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    tipo_accion VARCHAR(50),
    entidad_afectada VARCHAR(50),
    valores_antiguos JSONB,
    valores_nuevos JSONB,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    INDEX idx_usuario_fecha (id_usuario, timestamp)
);

-- Índices para optimización
CREATE INDEX idx_validaciones_dispositivo ON validaciones_biometricas(dispositivo_id);
CREATE INDEX idx_credenciales_tipo ON credenciales_biometricas(tipo_biometria);
CREATE INDEX idx_usuarios_estado ON usuarios(estado);
CREATE INDEX idx_sesiones_token ON sesiones(token_acceso);

-- =====================================================
-- FIN DE MIGRACIONES
-- =====================================================
