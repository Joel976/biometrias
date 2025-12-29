-- =====================================================
-- MIGRACIÓN 006: SISTEMA COMPLETO DE AUDITORÍA
-- Sistema de Autenticación Biométrica
-- Fecha: 19 de diciembre de 2025
-- =====================================================

-- ============================================
-- 1. MEJORAR TABLA DE LOGS DE AUDITORÍA
-- ============================================

-- Eliminar tabla antigua si existe
DROP TABLE IF EXISTS logs_auditoria CASCADE;

-- Crear tabla mejorada de auditoría
CREATE TABLE IF NOT EXISTS logs_auditoria (
    id_log BIGSERIAL PRIMARY KEY,
    
    -- Información del usuario
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    nombre_usuario VARCHAR(200), -- Guardamos el nombre en caso de que el usuario sea eliminado
    
    -- Información de la acción
    tipo_accion VARCHAR(50) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'FAILED_LOGIN', etc.
    entidad_afectada VARCHAR(100) NOT NULL, -- Nombre de la tabla afectada
    id_entidad_afectada INTEGER, -- ID del registro afectado
    descripcion_accion TEXT, -- Descripción legible de la acción
    
    -- Datos de cambios
    valores_antiguos JSONB, -- Estado anterior (para UPDATE/DELETE)
    valores_nuevos JSONB, -- Estado nuevo (para INSERT/UPDATE)
    campos_modificados TEXT[], -- Array de campos que cambiaron
    
    -- Contexto de la petición
    metodo_http VARCHAR(10), -- GET, POST, PUT, DELETE
    endpoint VARCHAR(200), -- URL del endpoint
    ip_origen VARCHAR(50),
    user_agent TEXT,
    headers_http JSONB, -- Headers relevantes
    
    -- Información del dispositivo
    dispositivo_id VARCHAR(100),
    tipo_dispositivo VARCHAR(50), -- 'web', 'mobile_android', 'mobile_ios'
    version_app VARCHAR(20),
    sistema_operativo VARCHAR(100),
    
    -- Temporal y geográfica
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_utc TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC'),
    zona_horaria VARCHAR(50),
    ubicacion_gps VARCHAR(100),
    pais VARCHAR(50),
    ciudad VARCHAR(100),
    
    -- Resultado de la operación
    resultado VARCHAR(20) NOT NULL DEFAULT 'exito', -- 'exito', 'error', 'advertencia'
    codigo_http INTEGER,
    mensaje_error TEXT,
    stack_trace TEXT,
    
    -- Seguridad
    nivel_riesgo VARCHAR(20) DEFAULT 'bajo', -- 'bajo', 'medio', 'alto', 'critico'
    requiere_revision BOOLEAN DEFAULT FALSE,
    revisado BOOLEAN DEFAULT FALSE,
    fecha_revision TIMESTAMP,
    id_revisor INTEGER REFERENCES usuarios(id_usuario),
    notas_revision TEXT,
    
    -- Duración de la operación
    duracion_ms INTEGER, -- Duración en milisegundos
    
    -- Categorización
    categoria VARCHAR(50), -- 'autenticacion', 'biometria', 'datos_personales', 'configuracion'
    subcategoria VARCHAR(50),
    etiquetas TEXT[], -- Tags para búsqueda
    
    -- Índices
    CONSTRAINT check_resultado CHECK (resultado IN ('exito', 'error', 'advertencia')),
    CONSTRAINT check_nivel_riesgo CHECK (nivel_riesgo IN ('bajo', 'medio', 'alto', 'critico'))
);

-- Índices optimizados
CREATE INDEX idx_auditoria_usuario ON logs_auditoria(id_usuario);
CREATE INDEX idx_auditoria_timestamp ON logs_auditoria(timestamp DESC);
CREATE INDEX idx_auditoria_tipo_accion ON logs_auditoria(tipo_accion);
CREATE INDEX idx_auditoria_entidad ON logs_auditoria(entidad_afectada);
CREATE INDEX idx_auditoria_resultado ON logs_auditoria(resultado);
CREATE INDEX idx_auditoria_nivel_riesgo ON logs_auditoria(nivel_riesgo);
CREATE INDEX idx_auditoria_dispositivo ON logs_auditoria(dispositivo_id);
CREATE INDEX idx_auditoria_ip ON logs_auditoria(ip_origen);
CREATE INDEX idx_auditoria_categoria ON logs_auditoria(categoria);
CREATE INDEX idx_auditoria_revision ON logs_auditoria(requiere_revision, revisado);

-- Índice compuesto para búsquedas comunes
CREATE INDEX idx_auditoria_usuario_fecha ON logs_auditoria(id_usuario, timestamp DESC);
CREATE INDEX idx_auditoria_entidad_fecha ON logs_auditoria(entidad_afectada, timestamp DESC);

-- Índice GIN para búsqueda en arrays
CREATE INDEX idx_auditoria_etiquetas ON logs_auditoria USING GIN(etiquetas);

-- ============================================
-- 2. TABLA DE INTENTOS DE AUTENTICACIÓN
-- ============================================

CREATE TABLE IF NOT EXISTS intentos_autenticacion (
    id_intento BIGSERIAL PRIMARY KEY,
    
    -- Usuario (puede ser NULL si el usuario no existe)
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    identificador_ingresado VARCHAR(100) NOT NULL,
    
    -- Tipo de autenticación
    tipo_autenticacion VARCHAR(50) NOT NULL, -- 'biometrica_oreja', 'biometrica_voz', 'password'
    resultado VARCHAR(20) NOT NULL, -- 'exito', 'fallo_credencial', 'fallo_usuario_inexistente', 'bloqueado'
    
    -- Detalles biométricos (si aplica)
    puntuacion_confianza FLOAT,
    umbral_requerido FLOAT,
    tipo_biometria VARCHAR(20),
    
    -- Contexto
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    dispositivo_id VARCHAR(100),
    user_agent TEXT,
    ubicacion_gps VARCHAR(100),
    
    -- Seguridad
    intentos_consecutivos INTEGER DEFAULT 1,
    es_sospechoso BOOLEAN DEFAULT FALSE,
    razon_sospecha TEXT,
    
    -- Duración
    duracion_ms INTEGER,
    
    CONSTRAINT check_resultado_auth CHECK (resultado IN ('exito', 'fallo_credencial', 'fallo_usuario_inexistente', 'bloqueado', 'error'))
);

CREATE INDEX idx_intentos_usuario ON intentos_autenticacion(id_usuario);
CREATE INDEX idx_intentos_timestamp ON intentos_autenticacion(timestamp DESC);
CREATE INDEX idx_intentos_ip ON intentos_autenticacion(ip_origen);
CREATE INDEX idx_intentos_resultado ON intentos_autenticacion(resultado);
CREATE INDEX idx_intentos_sospechoso ON intentos_autenticacion(es_sospechoso);

-- ============================================
-- 3. TABLA DE CAMBIOS EN DATOS SENSIBLES
-- ============================================

CREATE TABLE IF NOT EXISTS auditoria_datos_sensibles (
    id_auditoria BIGSERIAL PRIMARY KEY,
    
    -- Usuario afectado
    id_usuario INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    nombre_completo VARCHAR(200),
    
    -- Tipo de dato modificado
    tipo_dato VARCHAR(50) NOT NULL, -- 'credencial_biometrica', 'datos_personales', 'configuracion_seguridad'
    campo_modificado VARCHAR(100) NOT NULL,
    
    -- Valores (encriptados si es necesario)
    valor_anterior TEXT,
    valor_nuevo TEXT,
    hash_valor_anterior VARCHAR(256), -- Para verificación sin exponer el valor
    hash_valor_nuevo VARCHAR(256),
    
    -- Quién hizo el cambio
    id_usuario_ejecutor INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    nombre_ejecutor VARCHAR(200),
    tipo_ejecutor VARCHAR(50), -- 'usuario', 'administrador', 'sistema', 'api'
    
    -- Contexto
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    motivo_cambio TEXT,
    
    -- Aprobación (para cambios críticos)
    requiere_aprobacion BOOLEAN DEFAULT FALSE,
    aprobado BOOLEAN,
    fecha_aprobacion TIMESTAMP,
    id_aprobador INTEGER REFERENCES usuarios(id_usuario),
    comentarios_aprobacion TEXT
);

CREATE INDEX idx_datos_sensibles_usuario ON auditoria_datos_sensibles(id_usuario);
CREATE INDEX idx_datos_sensibles_timestamp ON auditoria_datos_sensibles(timestamp DESC);
CREATE INDEX idx_datos_sensibles_tipo ON auditoria_datos_sensibles(tipo_dato);
CREATE INDEX idx_datos_sensibles_aprobacion ON auditoria_datos_sensibles(requiere_aprobacion, aprobado);

-- ============================================
-- 4. TABLA DE EVENTOS DE SEGURIDAD
-- ============================================

CREATE TABLE IF NOT EXISTS eventos_seguridad (
    id_evento BIGSERIAL PRIMARY KEY,
    
    -- Tipo de evento
    tipo_evento VARCHAR(100) NOT NULL, -- 'multiple_failed_logins', 'suspicious_location', 'new_device', etc.
    severidad VARCHAR(20) NOT NULL, -- 'info', 'warning', 'error', 'critical'
    
    -- Usuario afectado (puede ser NULL)
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    
    -- Detalles del evento
    descripcion TEXT NOT NULL,
    detalles_json JSONB,
    
    -- Contexto
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    dispositivo_id VARCHAR(100),
    ubicacion VARCHAR(100),
    
    -- Respuesta automática
    accion_automatica VARCHAR(100), -- 'bloquear_usuario', 'requerir_2fa', 'alerta_admin', 'ninguna'
    accion_ejecutada BOOLEAN DEFAULT FALSE,
    timestamp_accion TIMESTAMP,
    
    -- Revisión manual
    requiere_revision BOOLEAN DEFAULT FALSE,
    revisado BOOLEAN DEFAULT FALSE,
    fecha_revision TIMESTAMP,
    id_revisor INTEGER REFERENCES usuarios(id_usuario),
    resolucion TEXT,
    
    CONSTRAINT check_severidad CHECK (severidad IN ('info', 'warning', 'error', 'critical'))
);

CREATE INDEX idx_eventos_timestamp ON eventos_seguridad(timestamp DESC);
CREATE INDEX idx_eventos_severidad ON eventos_seguridad(severidad);
CREATE INDEX idx_eventos_usuario ON eventos_seguridad(id_usuario);
CREATE INDEX idx_eventos_revision ON eventos_seguridad(requiere_revision, revisado);

-- ============================================
-- 5. TABLA DE ACCIONES ADMINISTRATIVAS
-- ============================================

CREATE TABLE IF NOT EXISTS auditoria_admin (
    id_auditoria BIGSERIAL PRIMARY KEY,
    
    -- Administrador que ejecuta la acción
    id_admin INTEGER NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    nombre_admin VARCHAR(200),
    rol_admin VARCHAR(50),
    
    -- Acción realizada
    accion VARCHAR(100) NOT NULL, -- 'crear_usuario', 'eliminar_usuario', 'cambiar_permisos', etc.
    entidad_afectada VARCHAR(100),
    id_entidad INTEGER,
    
    -- Detalles
    descripcion TEXT,
    parametros_json JSONB,
    valores_anteriores JSONB,
    valores_nuevos JSONB,
    
    -- Contexto
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    
    -- Justificación
    motivo TEXT,
    ticket_soporte VARCHAR(100), -- Número de ticket si aplica
    
    -- Resultado
    resultado VARCHAR(20) DEFAULT 'exito',
    mensaje_error TEXT
);

CREATE INDEX idx_admin_timestamp ON auditoria_admin(timestamp DESC);
CREATE INDEX idx_admin_id_admin ON auditoria_admin(id_admin);
CREATE INDEX idx_admin_accion ON auditoria_admin(accion);

-- ============================================
-- 6. FUNCIÓN PARA LOGGING AUTOMÁTICO
-- ============================================

CREATE OR REPLACE FUNCTION log_auditoria_automatica()
RETURNS TRIGGER AS $$
DECLARE
    usuario_actual INTEGER;
    accion_tipo VARCHAR(50);
    descripcion_texto TEXT;
BEGIN
    -- Obtener usuario actual (puede venir de una variable de sesión)
    usuario_actual := current_setting('app.current_user_id', true)::INTEGER;
    
    -- Determinar tipo de acción
    IF TG_OP = 'INSERT' THEN
        accion_tipo := 'INSERT';
        descripcion_texto := 'Nuevo registro creado en ' || TG_TABLE_NAME;
    ELSIF TG_OP = 'UPDATE' THEN
        accion_tipo := 'UPDATE';
        descripcion_texto := 'Registro actualizado en ' || TG_TABLE_NAME;
    ELSIF TG_OP = 'DELETE' THEN
        accion_tipo := 'DELETE';
        descripcion_texto := 'Registro eliminado en ' || TG_TABLE_NAME;
    END IF;
    
    -- Insertar en logs de auditoría
    INSERT INTO logs_auditoria (
        id_usuario,
        tipo_accion,
        entidad_afectada,
        id_entidad_afectada,
        descripcion_accion,
        valores_antiguos,
        valores_nuevos,
        resultado,
        categoria
    ) VALUES (
        usuario_actual,
        accion_tipo,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN (OLD.id_usuario)
            ELSE (NEW.id_usuario)
        END,
        descripcion_texto,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) ELSE NULL END,
        'exito',
        'sistema'
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. TRIGGERS PARA AUDITORÍA AUTOMÁTICA
-- ============================================

-- Trigger para usuarios
DROP TRIGGER IF EXISTS trigger_auditoria_usuarios ON usuarios;
CREATE TRIGGER trigger_auditoria_usuarios
    AFTER INSERT OR UPDATE OR DELETE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();

-- Trigger para credenciales biométricas
DROP TRIGGER IF EXISTS trigger_auditoria_credenciales ON credenciales_biometricas;
CREATE TRIGGER trigger_auditoria_credenciales
    AFTER INSERT OR UPDATE OR DELETE ON credenciales_biometricas
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();

-- Trigger para sesiones
DROP TRIGGER IF EXISTS trigger_auditoria_sesiones ON sesiones;
CREATE TRIGGER trigger_auditoria_sesiones
    AFTER INSERT OR UPDATE OR DELETE ON sesiones
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();

-- ============================================
-- 8. VISTAS PARA REPORTES DE AUDITORÍA
-- ============================================

-- Vista de actividad de usuarios
CREATE OR REPLACE VIEW vista_actividad_usuarios AS
SELECT 
    u.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    u.identificador_unico,
    COUNT(DISTINCT la.id_log) AS total_acciones,
    COUNT(DISTINCT CASE WHEN la.tipo_accion = 'LOGIN' THEN la.id_log END) AS total_logins,
    MAX(la.timestamp) AS ultima_actividad,
    COUNT(DISTINCT la.ip_origen) AS ips_distintas,
    COUNT(DISTINCT la.dispositivo_id) AS dispositivos_distintos
FROM usuarios u
LEFT JOIN logs_auditoria la ON u.id_usuario = la.id_usuario
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.identificador_unico;

-- Vista de intentos fallidos de autenticación
CREATE OR REPLACE VIEW vista_intentos_fallidos AS
SELECT 
    ia.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_usuario,
    ia.identificador_ingresado,
    ia.tipo_autenticacion,
    COUNT(*) AS intentos_fallidos,
    MAX(ia.timestamp) AS ultimo_intento,
    array_agg(DISTINCT ia.ip_origen) AS ips_origen,
    bool_or(ia.es_sospechoso) AS tiene_actividad_sospechosa
FROM intentos_autenticacion ia
LEFT JOIN usuarios u ON ia.id_usuario = u.id_usuario
WHERE ia.resultado != 'exito'
GROUP BY ia.id_usuario, u.nombres, u.apellidos, ia.identificador_ingresado, ia.tipo_autenticacion
HAVING COUNT(*) >= 3; -- Mostrar solo usuarios con 3+ intentos fallidos

-- Vista de eventos críticos de seguridad
CREATE OR REPLACE VIEW vista_eventos_criticos AS
SELECT 
    es.id_evento,
    es.tipo_evento,
    es.severidad,
    u.nombres || ' ' || u.apellidos AS usuario_afectado,
    es.descripcion,
    es.timestamp,
    es.ip_origen,
    es.revisado,
    es.resolucion
FROM eventos_seguridad es
LEFT JOIN usuarios u ON es.id_usuario = u.id_usuario
WHERE es.severidad IN ('error', 'critical')
ORDER BY es.timestamp DESC;

-- Vista de cambios en datos sensibles
CREATE OR REPLACE VIEW vista_cambios_sensibles AS
SELECT 
    ads.id_auditoria,
    u.nombres || ' ' || u.apellidos AS usuario_afectado,
    ads.tipo_dato,
    ads.campo_modificado,
    ue.nombres || ' ' || ue.apellidos AS ejecutor,
    ads.timestamp,
    ads.aprobado,
    ads.motivo_cambio
FROM auditoria_datos_sensibles ads
JOIN usuarios u ON ads.id_usuario = u.id_usuario
LEFT JOIN usuarios ue ON ads.id_usuario_ejecutor = ue.id_usuario
ORDER BY ads.timestamp DESC;

-- ============================================
-- 9. FUNCIONES DE UTILIDAD PARA AUDITORÍA
-- ============================================

-- Función para obtener resumen de actividad de un usuario
CREATE OR REPLACE FUNCTION obtener_resumen_auditoria_usuario(p_id_usuario INTEGER)
RETURNS TABLE (
    total_acciones BIGINT,
    acciones_exitosas BIGINT,
    acciones_fallidas BIGINT,
    ultimo_login TIMESTAMP,
    total_dispositivos BIGINT,
    ips_utilizadas TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) AS total_acciones,
        COUNT(CASE WHEN resultado = 'exito' THEN 1 END) AS acciones_exitosas,
        COUNT(CASE WHEN resultado != 'exito' THEN 1 END) AS acciones_fallidas,
        MAX(CASE WHEN tipo_accion = 'LOGIN' THEN timestamp END) AS ultimo_login,
        COUNT(DISTINCT dispositivo_id) AS total_dispositivos,
        array_agg(DISTINCT ip_origen) AS ips_utilizadas
    FROM logs_auditoria
    WHERE id_usuario = p_id_usuario;
END;
$$ LANGUAGE plpgsql;

-- Función para detectar actividad sospechosa
CREATE OR REPLACE FUNCTION detectar_actividad_sospechosa(p_id_usuario INTEGER)
RETURNS TABLE (
    es_sospechoso BOOLEAN,
    razones TEXT[]
) AS $$
DECLARE
    razones_sospecha TEXT[] := '{}';
    intentos_fallidos_recientes INTEGER;
    dispositivos_distintos INTEGER;
    ubicaciones_distintas INTEGER;
BEGIN
    -- Verificar intentos fallidos en las últimas 24 horas
    SELECT COUNT(*) INTO intentos_fallidos_recientes
    FROM intentos_autenticacion
    WHERE id_usuario = p_id_usuario
      AND resultado != 'exito'
      AND timestamp > NOW() - INTERVAL '24 hours';
    
    IF intentos_fallidos_recientes >= 5 THEN
        razones_sospecha := array_append(razones_sospecha, 
            'Múltiples intentos fallidos de autenticación (' || intentos_fallidos_recientes || ')');
    END IF;
    
    -- Verificar dispositivos distintos en 24 horas
    SELECT COUNT(DISTINCT dispositivo_id) INTO dispositivos_distintos
    FROM logs_auditoria
    WHERE id_usuario = p_id_usuario
      AND timestamp > NOW() - INTERVAL '24 hours';
    
    IF dispositivos_distintos >= 3 THEN
        razones_sospecha := array_append(razones_sospecha, 
            'Múltiples dispositivos en 24 horas (' || dispositivos_distintos || ')');
    END IF;
    
    -- Retornar resultado
    RETURN QUERY SELECT 
        (array_length(razones_sospecha, 1) > 0),
        razones_sospecha;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. POLÍTICA DE RETENCIÓN DE DATOS
-- ============================================

-- Función para archivar logs antiguos (ejecutar periódicamente)
CREATE OR REPLACE FUNCTION archivar_logs_antiguos(p_dias_antiguedad INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    registros_archivados INTEGER;
BEGIN
    -- Crear tabla de archivo si no existe
    CREATE TABLE IF NOT EXISTS logs_auditoria_archivo (
        LIKE logs_auditoria INCLUDING ALL
    );
    
    -- Mover registros antiguos al archivo
    WITH registros_movidos AS (
        DELETE FROM logs_auditoria
        WHERE timestamp < NOW() - (p_dias_antiguedad || ' days')::INTERVAL
        RETURNING *
    )
    INSERT INTO logs_auditoria_archivo
    SELECT * FROM registros_movidos;
    
    GET DIAGNOSTICS registros_archivados = ROW_COUNT;
    
    RETURN registros_archivados;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMENTARIOS EN TABLAS Y COLUMNAS
-- =====================================================

COMMENT ON TABLE logs_auditoria IS 'Registro completo de todas las acciones del sistema con contexto detallado';
COMMENT ON TABLE intentos_autenticacion IS 'Registro específico de intentos de login para análisis de seguridad';
COMMENT ON TABLE auditoria_datos_sensibles IS 'Auditoría de cambios en datos sensibles con aprobación';
COMMENT ON TABLE eventos_seguridad IS 'Eventos de seguridad detectados automáticamente';
COMMENT ON TABLE auditoria_admin IS 'Registro de acciones administrativas críticas';

-- =====================================================
-- FIN DE MIGRACIÓN 006
-- =====================================================
