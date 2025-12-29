-- =====================================================
-- MIGRATION 006: COMPLETE AUDIT SYSTEM
-- Biometric Authentication System
-- Date: December 19, 2025
-- =====================================================

-- ============================================
-- 1. ENHANCED AUDIT LOGS TABLE
-- ============================================

-- Drop old table if exists
DROP TABLE IF EXISTS logs_auditoria CASCADE;

-- Create enhanced audit table
CREATE TABLE logs_auditoria (
    id_log BIGSERIAL PRIMARY KEY,
    
    -- User information
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    nombre_usuario VARCHAR(200),
    
    -- Action details
    tipo_accion VARCHAR(50) NOT NULL,
    entidad_afectada VARCHAR(100) NOT NULL,
    id_entidad_afectada INTEGER,
    descripcion_accion TEXT,
    
    -- Change tracking
    valores_antiguos JSONB,
    valores_nuevos JSONB,
    campos_modificados TEXT[],
    
    -- HTTP context
    metodo_http VARCHAR(10),
    endpoint VARCHAR(200),
    ip_origen VARCHAR(50),
    user_agent TEXT,
    headers_http JSONB,
    
    -- Device information
    dispositivo_id VARCHAR(100),
    tipo_dispositivo VARCHAR(50),
    version_app VARCHAR(20),
    sistema_operativo VARCHAR(100),
    
    -- Temporal and geographic data
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    timestamp_utc TIMESTAMP DEFAULT (CURRENT_TIMESTAMP AT TIME ZONE 'UTC'),
    zona_horaria VARCHAR(50),
    ubicacion_gps VARCHAR(100),
    pais VARCHAR(50),
    ciudad VARCHAR(100),
    
    -- Result and security
    resultado VARCHAR(20) DEFAULT 'exito',
    codigo_http INTEGER,
    mensaje_error TEXT,
    stack_trace TEXT,
    nivel_riesgo VARCHAR(20) DEFAULT 'bajo',
    requiere_revision BOOLEAN DEFAULT FALSE,
    revisado BOOLEAN DEFAULT FALSE,
    id_revisor INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    fecha_revision TIMESTAMP,
    notas_revision TEXT,
    
    -- Performance
    duracion_ms INTEGER,
    
    -- Categorization
    categoria VARCHAR(50),
    subcategoria VARCHAR(50),
    etiquetas TEXT[],
    
    -- Constraints
    CONSTRAINT check_resultado CHECK (resultado IN ('exito', 'error', 'advertencia')),
    CONSTRAINT check_nivel_riesgo CHECK (nivel_riesgo IN ('bajo', 'medio', 'alto', 'critico'))
);

-- Optimized indexes
CREATE INDEX idx_auditoria_usuario ON logs_auditoria(id_usuario);
CREATE INDEX idx_auditoria_timestamp ON logs_auditoria(timestamp DESC);
CREATE INDEX idx_auditoria_tipo_accion ON logs_auditoria(tipo_accion);
CREATE INDEX idx_auditoria_entidad ON logs_auditoria(entidad_afectada);
CREATE INDEX idx_auditoria_resultado ON logs_auditoria(resultado);
CREATE INDEX idx_auditoria_nivel_riesgo ON logs_auditoria(nivel_riesgo);
CREATE INDEX idx_auditoria_revision ON logs_auditoria(requiere_revision, revisado);
CREATE INDEX idx_auditoria_categoria ON logs_auditoria(categoria);
CREATE INDEX idx_auditoria_ip ON logs_auditoria(ip_origen);
CREATE INDEX idx_auditoria_dispositivo ON logs_auditoria(dispositivo_id);
CREATE INDEX idx_auditoria_usuario_fecha ON logs_auditoria(id_usuario, timestamp DESC);
CREATE INDEX idx_auditoria_entidad_fecha ON logs_auditoria(entidad_afectada, timestamp DESC);
CREATE INDEX idx_auditoria_etiquetas ON logs_auditoria USING GIN(etiquetas);


-- ============================================
-- 2. AUTHENTICATION ATTEMPTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS intentos_autenticacion (
    id_intento BIGSERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    identificador_ingresado VARCHAR(200),
    tipo_autenticacion VARCHAR(50) NOT NULL,
    resultado VARCHAR(20) NOT NULL,
    
    -- Biometric details
    puntuacion_confianza DECIMAL(5,4),
    umbral_requerido DECIMAL(5,4),
    tipo_biometria VARCHAR(50),
    
    -- Context
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    dispositivo_id VARCHAR(100),
    user_agent TEXT,
    ubicacion_gps VARCHAR(100),
    
    -- Security
    intentos_consecutivos INTEGER DEFAULT 1,
    es_sospechoso BOOLEAN DEFAULT FALSE,
    razon_sospecha TEXT,
    accion_tomada VARCHAR(100),
    
    -- Performance
    duracion_ms INTEGER,
    
    CONSTRAINT check_auth_resultado CHECK (resultado IN ('exito', 'fallo_credencial', 'fallo_biometria', 'fallo_dispositivo', 'bloqueado', 'error'))
);

CREATE INDEX idx_intentos_usuario ON intentos_autenticacion(id_usuario);
CREATE INDEX idx_intentos_timestamp ON intentos_autenticacion(timestamp DESC);
CREATE INDEX idx_intentos_ip ON intentos_autenticacion(ip_origen);
CREATE INDEX idx_intentos_resultado ON intentos_autenticacion(resultado);
CREATE INDEX idx_intentos_sospechoso ON intentos_autenticacion(es_sospechoso);


-- ============================================
-- 3. SENSITIVE DATA AUDIT TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS auditoria_datos_sensibles (
    id_auditoria BIGSERIAL PRIMARY KEY,
    
    -- Target user
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    nombre_completo VARCHAR(300),
    
    -- Change details
    tipo_dato VARCHAR(50) NOT NULL,
    campo_modificado VARCHAR(100) NOT NULL,
    valor_anterior TEXT,
    valor_nuevo TEXT,
    hash_valor_anterior VARCHAR(64),
    hash_valor_nuevo VARCHAR(64),
    
    -- Executor
    id_usuario_ejecutor INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    nombre_ejecutor VARCHAR(200),
    tipo_ejecutor VARCHAR(50) DEFAULT 'usuario',
    
    -- Context
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    motivo_cambio TEXT,
    
    -- Approval workflow
    requiere_aprobacion BOOLEAN DEFAULT FALSE,
    aprobado BOOLEAN,
    id_aprobador INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    fecha_aprobacion TIMESTAMP,
    justificacion_aprobacion TEXT,
    
    CONSTRAINT check_tipo_dato_sensible CHECK (tipo_dato IN ('credencial_biometrica', 'datos_personales', 'permisos', 'configuracion_seguridad'))
);

CREATE INDEX idx_datos_sensibles_usuario ON auditoria_datos_sensibles(id_usuario);
CREATE INDEX idx_datos_sensibles_timestamp ON auditoria_datos_sensibles(timestamp DESC);
CREATE INDEX idx_datos_sensibles_tipo ON auditoria_datos_sensibles(tipo_dato);
CREATE INDEX idx_datos_sensibles_aprobacion ON auditoria_datos_sensibles(requiere_aprobacion, aprobado);


-- ============================================
-- 4. SECURITY EVENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS eventos_seguridad (
    id_evento BIGSERIAL PRIMARY KEY,
    
    -- Event classification
    tipo_evento VARCHAR(100) NOT NULL,
    severidad VARCHAR(20) NOT NULL,
    
    -- Details
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    descripcion TEXT NOT NULL,
    detalles_json JSONB,
    
    -- Context
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    dispositivo_id VARCHAR(100),
    ubicacion VARCHAR(100),
    
    -- Response
    accion_automatica VARCHAR(100) DEFAULT 'ninguna',
    requiere_revision BOOLEAN DEFAULT FALSE,
    revisado BOOLEAN DEFAULT FALSE,
    id_revisor INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    fecha_revision TIMESTAMP,
    accion_tomada TEXT,
    
    CONSTRAINT check_severidad CHECK (severidad IN ('info', 'warning', 'error', 'critical'))
);

CREATE INDEX idx_eventos_timestamp ON eventos_seguridad(timestamp DESC);
CREATE INDEX idx_eventos_severidad ON eventos_seguridad(severidad);
CREATE INDEX idx_eventos_usuario ON eventos_seguridad(id_usuario);
CREATE INDEX idx_eventos_revision ON eventos_seguridad(requiere_revision, revisado);


-- ============================================
-- 5. ADMIN ACTIONS AUDIT TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS auditoria_admin (
    id_auditoria BIGSERIAL PRIMARY KEY,
    
    -- Admin details
    id_admin INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    nombre_admin VARCHAR(200),
    rol_admin VARCHAR(50),
    
    -- Action details
    accion VARCHAR(100) NOT NULL,
    entidad_afectada VARCHAR(100),
    id_entidad INTEGER,
    descripcion TEXT,
    parametros_json JSONB,
    
    -- Changes
    valores_anteriores JSONB,
    valores_nuevos JSONB,
    
    -- Context
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_origen VARCHAR(50),
    motivo TEXT,
    ticket_soporte VARCHAR(50),
    
    -- Result
    resultado VARCHAR(20) DEFAULT 'exito',
    mensaje_error TEXT,
    
    CONSTRAINT check_admin_resultado CHECK (resultado IN ('exito', 'error', 'parcial'))
);

CREATE INDEX idx_admin_timestamp ON auditoria_admin(timestamp DESC);
CREATE INDEX idx_admin_id_admin ON auditoria_admin(id_admin);
CREATE INDEX idx_admin_accion ON auditoria_admin(accion);


-- ============================================
-- 6. AUTOMATIC AUDIT TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION log_auditoria_automatica()
RETURNS TRIGGER AS $$
DECLARE
    v_id_usuario INTEGER;
    v_tipo_accion VARCHAR(50);
BEGIN
    -- Try to get current user ID from session variable
    BEGIN
        v_id_usuario := current_setting('app.current_user_id', true)::INTEGER;
    EXCEPTION WHEN OTHERS THEN
        v_id_usuario := NULL;
    END;
    
    -- Determine action type
    v_tipo_accion := TG_OP;
    
    -- Insert audit log
    INSERT INTO logs_auditoria (
        id_usuario,
        tipo_accion,
        entidad_afectada,
        id_entidad_afectada,
        valores_antiguos,
        valores_nuevos,
        resultado
    ) VALUES (
        v_id_usuario,
        v_tipo_accion,
        TG_TABLE_NAME,
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.id_usuario
            ELSE NEW.id_usuario
        END,
        CASE 
            WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)
            ELSE NULL
        END,
        CASE 
            WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)
            ELSE NULL
        END,
        'exito'
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 7. CREATE TRIGGERS ON CRITICAL TABLES
-- ============================================

-- Trigger for usuarios table
DROP TRIGGER IF EXISTS trigger_auditoria_usuarios ON usuarios;
CREATE TRIGGER trigger_auditoria_usuarios
    AFTER INSERT OR UPDATE OR DELETE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();

-- Trigger for credenciales_biometricas table
DROP TRIGGER IF EXISTS trigger_auditoria_credenciales ON credenciales_biometricas;
CREATE TRIGGER trigger_auditoria_credenciales
    AFTER INSERT OR UPDATE OR DELETE ON credenciales_biometricas
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();

-- Trigger for sesiones table
DROP TRIGGER IF EXISTS trigger_auditoria_sesiones ON sesiones;
CREATE TRIGGER trigger_auditoria_sesiones
    AFTER INSERT OR UPDATE OR DELETE ON sesiones
    FOR EACH ROW
    EXECUTE FUNCTION log_auditoria_automatica();


-- ============================================
-- 8. REPORTING VIEWS
-- ============================================

-- View: User activity summary
CREATE OR REPLACE VIEW vista_actividad_usuarios AS
SELECT 
    u.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    u.identificador_unico,
    COUNT(DISTINCT la.id_log) AS total_acciones,
    COUNT(DISTINCT ia.id_intento) AS total_intentos_auth,
    COUNT(DISTINCT CASE WHEN ia.resultado = 'exito' THEN ia.id_intento END) AS intentos_exitosos,
    COUNT(DISTINCT CASE WHEN ia.resultado != 'exito' THEN ia.id_intento END) AS intentos_fallidos,
    MAX(ia.timestamp) AS ultimo_login,
    COUNT(DISTINCT la.ip_origen) AS ips_distintas,
    COUNT(DISTINCT la.dispositivo_id) AS dispositivos_distintos
FROM usuarios u
LEFT JOIN logs_auditoria la ON u.id_usuario = la.id_usuario
LEFT JOIN intentos_autenticacion ia ON u.id_usuario = ia.id_usuario
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.identificador_unico;

-- View: Failed login attempts (security monitoring)
CREATE OR REPLACE VIEW vista_intentos_fallidos AS
SELECT 
    u.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    u.identificador_unico,
    COUNT(*) AS intentos_fallidos,
    MAX(ia.timestamp) AS ultimo_intento_fallido,
    COUNT(DISTINCT ia.ip_origen) AS ips_distintas,
    ARRAY_AGG(DISTINCT ia.ip_origen) AS lista_ips,
    SUM(CASE WHEN ia.es_sospechoso THEN 1 ELSE 0 END) AS intentos_sospechosos
FROM intentos_autenticacion ia
LEFT JOIN usuarios u ON ia.id_usuario = u.id_usuario
WHERE ia.resultado != 'exito'
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.identificador_unico
HAVING COUNT(*) >= 3;

-- View: Critical security events
CREATE OR REPLACE VIEW vista_eventos_criticos AS
SELECT 
    es.id_evento,
    es.tipo_evento,
    es.severidad,
    es.timestamp,
    u.nombres || ' ' || u.apellidos AS usuario_afectado,
    es.descripcion,
    es.ip_origen,
    es.revisado,
    r.nombres || ' ' || r.apellidos AS revisor
FROM eventos_seguridad es
LEFT JOIN usuarios u ON es.id_usuario = u.id_usuario
LEFT JOIN usuarios r ON es.id_revisor = r.id_usuario
WHERE es.severidad IN ('error', 'critical')
ORDER BY es.timestamp DESC;

-- View: Sensitive data changes
CREATE OR REPLACE VIEW vista_cambios_sensibles AS
SELECT 
    ads.id_auditoria,
    ads.timestamp,
    u.nombres || ' ' || u.apellidos AS usuario_afectado,
    ads.tipo_dato,
    ads.campo_modificado,
    e.nombres || ' ' || e.apellidos AS ejecutor,
    ads.tipo_ejecutor,
    ads.requiere_aprobacion,
    ads.aprobado,
    a.nombres || ' ' || a.apellidos AS aprobador,
    ads.motivo_cambio
FROM auditoria_datos_sensibles ads
LEFT JOIN usuarios u ON ads.id_usuario = u.id_usuario
LEFT JOIN usuarios e ON ads.id_usuario_ejecutor = e.id_usuario
LEFT JOIN usuarios a ON ads.id_aprobador = a.id_usuario
ORDER BY ads.timestamp DESC;


-- ============================================
-- 9. UTILITY FUNCTIONS
-- ============================================

-- Function: Get user audit summary
CREATE OR REPLACE FUNCTION obtener_resumen_auditoria_usuario(p_id_usuario INTEGER)
RETURNS TABLE (
    total_acciones BIGINT,
    acciones_exitosas BIGINT,
    acciones_con_error BIGINT,
    ultimo_login TIMESTAMP,
    total_intentos_auth BIGINT,
    intentos_auth_exitosos BIGINT,
    intentos_auth_fallidos BIGINT,
    total_dispositivos BIGINT,
    ips_utilizadas TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT la.id_log),
        COUNT(DISTINCT CASE WHEN la.resultado = 'exito' THEN la.id_log END),
        COUNT(DISTINCT CASE WHEN la.resultado = 'error' THEN la.id_log END),
        MAX(ia.timestamp),
        COUNT(DISTINCT ia.id_intento),
        COUNT(DISTINCT CASE WHEN ia.resultado = 'exito' THEN ia.id_intento END),
        COUNT(DISTINCT CASE WHEN ia.resultado != 'exito' THEN ia.id_intento END),
        COUNT(DISTINCT la.dispositivo_id),
        ARRAY_AGG(DISTINCT la.ip_origen)
    FROM logs_auditoria la
    FULL OUTER JOIN intentos_autenticacion ia ON la.id_usuario = ia.id_usuario
    WHERE la.id_usuario = p_id_usuario OR ia.id_usuario = p_id_usuario;
END;
$$ LANGUAGE plpgsql;

-- Function: Detect suspicious activity
CREATE OR REPLACE FUNCTION detectar_actividad_sospechosa(p_id_usuario INTEGER)
RETURNS TABLE (
    es_sospechoso BOOLEAN,
    razones TEXT[]
) AS $$
DECLARE
    v_razones TEXT[] := ARRAY[]::TEXT[];
    v_intentos_fallidos INTEGER;
    v_ips_distintas INTEGER;
    v_ubicaciones_distintas INTEGER;
BEGIN
    -- Check for multiple failed login attempts
    SELECT COUNT(*)
    INTO v_intentos_fallidos
    FROM intentos_autenticacion
    WHERE id_usuario = p_id_usuario 
    AND resultado != 'exito'
    AND timestamp > NOW() - INTERVAL '1 hour';
    
    IF v_intentos_fallidos >= 5 THEN
        v_razones := array_append(v_razones, 'Multiple failed login attempts in last hour');
    END IF;
    
    -- Check for multiple IPs
    SELECT COUNT(DISTINCT ip_origen)
    INTO v_ips_distintas
    FROM intentos_autenticacion
    WHERE id_usuario = p_id_usuario
    AND timestamp > NOW() - INTERVAL '24 hours';
    
    IF v_ips_distintas >= 5 THEN
        v_razones := array_append(v_razones, 'Multiple IP addresses in last 24 hours');
    END IF;
    
    -- Check for geographic anomalies
    SELECT COUNT(DISTINCT ubicacion_gps)
    INTO v_ubicaciones_distintas
    FROM intentos_autenticacion
    WHERE id_usuario = p_id_usuario
    AND timestamp > NOW() - INTERVAL '1 hour'
    AND ubicacion_gps IS NOT NULL;
    
    IF v_ubicaciones_distintas >= 3 THEN
        v_razones := array_append(v_razones, 'Multiple locations in short time period');
    END IF;
    
    RETURN QUERY SELECT 
        CASE WHEN array_length(v_razones, 1) > 0 THEN TRUE ELSE FALSE END,
        v_razones;
END;
$$ LANGUAGE plpgsql;

-- Function: Archive old logs (data retention)
CREATE OR REPLACE FUNCTION archivar_logs_antiguos(p_dias_antiguedad INTEGER DEFAULT 365)
RETURNS INTEGER AS $$
DECLARE
    v_registros_archivados INTEGER;
    v_fecha_corte TIMESTAMP;
BEGIN
    v_fecha_corte := NOW() - (p_dias_antiguedad || ' days')::INTERVAL;
    
    -- In a real system, you would move data to an archive table
    -- For now, we'll just count how many would be archived
    SELECT COUNT(*)
    INTO v_registros_archivados
    FROM logs_auditoria
    WHERE timestamp < v_fecha_corte;
    
    -- Optionally delete or move to archive
    -- DELETE FROM logs_auditoria WHERE timestamp < v_fecha_corte;
    
    RETURN v_registros_archivados;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- 10. COMMENTS AND DOCUMENTATION
-- ============================================

COMMENT ON TABLE logs_auditoria IS 'Comprehensive audit log for all system actions with 32 fields of context';
COMMENT ON TABLE intentos_autenticacion IS 'Tracks all authentication attempts including biometric data and security flags';
COMMENT ON TABLE auditoria_datos_sensibles IS 'Audit trail for sensitive data changes with approval workflow';
COMMENT ON TABLE eventos_seguridad IS 'Security events with severity classification and automated response tracking';
COMMENT ON TABLE auditoria_admin IS 'Administrative actions audit with support ticket integration';

-- =====================================================
-- END OF MIGRATION 006
-- =====================================================
