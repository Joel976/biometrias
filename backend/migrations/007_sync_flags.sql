-- =====================================================
-- MIGRATION 007: SYNC FLAGS SYSTEM
-- Biometric Authentication System
-- Date: December 19, 2025
-- =====================================================
-- Description: Adds flags to track synchronized data
--   1. Adds sync flags to existing tables
--   2. Creates sync tracking metadata
--   3. Adds indexes for sync queries
-- =====================================================

-- ============================================
-- 1. ADD SYNC FLAGS TO USUARIOS TABLE
-- ============================================

-- Add sync status columns to usuarios
ALTER TABLE usuarios 
ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS fecha_sincronizacion TIMESTAMP,
ADD COLUMN IF NOT EXISTS hash_sincronizacion VARCHAR(64),
ADD COLUMN IF NOT EXISTS version_sincronizacion INTEGER DEFAULT 1;

-- Index for sync queries
CREATE INDEX IF NOT EXISTS idx_usuarios_sincronizado ON usuarios(sincronizado, fecha_sincronizacion);

COMMENT ON COLUMN usuarios.sincronizado IS 'Flag indicating if user data has been synced to mobile';
COMMENT ON COLUMN usuarios.fecha_sincronizacion IS 'Timestamp of last successful sync';
COMMENT ON COLUMN usuarios.hash_sincronizacion IS 'SHA256 hash of synced data for integrity verification';
COMMENT ON COLUMN usuarios.version_sincronizacion IS 'Version counter incremented on each sync';


-- ============================================
-- 2. ADD SYNC FLAGS TO CREDENCIALES_BIOMETRICAS
-- ============================================

ALTER TABLE credenciales_biometricas
ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS fecha_sincronizacion TIMESTAMP,
ADD COLUMN IF NOT EXISTS hash_sincronizacion VARCHAR(64),
ADD COLUMN IF NOT EXISTS version_sincronizacion INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS dispositivos_sincronizados TEXT[]; -- Array of device IDs that have this credential

CREATE INDEX IF NOT EXISTS idx_credenciales_sincronizado ON credenciales_biometricas(sincronizado, fecha_sincronizacion);
CREATE INDEX IF NOT EXISTS idx_credenciales_dispositivos ON credenciales_biometricas USING GIN(dispositivos_sincronizados);

COMMENT ON COLUMN credenciales_biometricas.sincronizado IS 'Flag indicating if biometric credential has been synced';
COMMENT ON COLUMN credenciales_biometricas.dispositivos_sincronizados IS 'Array of device IDs that have received this credential';


-- ============================================
-- 3. ADD SYNC FLAGS TO TEXTOS_DINAMICOS_AUDIO
-- ============================================

ALTER TABLE textos_dinamicos_audio
ADD COLUMN IF NOT EXISTS sincronizado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS fecha_sincronizacion TIMESTAMP,
ADD COLUMN IF NOT EXISTS dispositivos_sincronizados TEXT[];

CREATE INDEX IF NOT EXISTS idx_textos_sincronizado ON textos_dinamicos_audio(sincronizado, fecha_sincronizacion);

COMMENT ON COLUMN textos_dinamicos_audio.sincronizado IS 'Flag indicating if dynamic text has been synced to devices';


-- ============================================
-- 4. ENHANCE SINCRONIZACIONES TABLE
-- ============================================

-- Add more detailed tracking to existing sincronizaciones table
ALTER TABLE sincronizaciones
ADD COLUMN IF NOT EXISTS cantidad_registros_enviados INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS cantidad_registros_recibidos INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS tamano_datos_kb DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS duracion_ms INTEGER,
ADD COLUMN IF NOT EXISTS hash_lote VARCHAR(64),
ADD COLUMN IF NOT EXISTS entidades_sincronizadas TEXT[]; -- ['usuarios', 'credenciales', 'textos']

CREATE INDEX IF NOT EXISTS idx_sync_entidades ON sincronizaciones USING GIN(entidades_sincronizadas);

COMMENT ON COLUMN sincronizaciones.cantidad_registros_enviados IS 'Number of records sent from server to device';
COMMENT ON COLUMN sincronizaciones.cantidad_registros_recibidos IS 'Number of records received from device';
COMMENT ON COLUMN sincronizaciones.entidades_sincronizadas IS 'Array of entity types included in this sync batch';


-- ============================================
-- 5. CREATE SYNC METADATA TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS metadata_sincronizacion (
    id_metadata SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    dispositivo_id VARCHAR(100) NOT NULL,
    entidad VARCHAR(50) NOT NULL, -- 'usuarios', 'credenciales_biometricas', 'textos_dinamicos'
    id_entidad INTEGER NOT NULL,
    
    -- Sync status
    estado_sync VARCHAR(20) DEFAULT 'pendiente', -- 'pendiente', 'sincronizado', 'conflicto', 'error'
    direccion VARCHAR(20) NOT NULL, -- 'servidor_a_dispositivo', 'dispositivo_a_servidor', 'bidireccional'
    
    -- Timestamps
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion TIMESTAMP,
    fecha_sincronizacion TIMESTAMP,
    fecha_ultimo_intento TIMESTAMP,
    
    -- Sync details
    version_local INTEGER DEFAULT 1,
    version_remota INTEGER,
    hash_local VARCHAR(64),
    hash_remoto VARCHAR(64),
    
    -- Conflict resolution
    tiene_conflicto BOOLEAN DEFAULT FALSE,
    resolucion_conflicto VARCHAR(50), -- 'servidor_gana', 'dispositivo_gana', 'manual', 'merge'
    datos_conflicto JSONB,
    
    -- Error tracking
    intentos_sync INTEGER DEFAULT 0,
    ultimo_error TEXT,
    
    CONSTRAINT unique_sync_entity UNIQUE (id_usuario, dispositivo_id, entidad, id_entidad)
);

CREATE INDEX idx_metadata_usuario_dispositivo ON metadata_sincronizacion(id_usuario, dispositivo_id);
CREATE INDEX idx_metadata_entidad ON metadata_sincronizacion(entidad, id_entidad);
CREATE INDEX idx_metadata_estado ON metadata_sincronizacion(estado_sync);
CREATE INDEX idx_metadata_conflicto ON metadata_sincronizacion(tiene_conflicto);
CREATE INDEX idx_metadata_fecha_sync ON metadata_sincronizacion(fecha_sincronizacion DESC);

COMMENT ON TABLE metadata_sincronizacion IS 'Granular tracking of sync status for each entity and device';


-- ============================================
-- 6. CREATE SYNC CHECKPOINTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS checkpoints_sincronizacion (
    id_checkpoint SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    dispositivo_id VARCHAR(100) NOT NULL,
    
    -- Checkpoint details
    nombre_checkpoint VARCHAR(100) NOT NULL,
    timestamp_checkpoint TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- State snapshot
    total_usuarios INTEGER DEFAULT 0,
    total_credenciales INTEGER DEFAULT 0,
    total_textos INTEGER DEFAULT 0,
    total_validaciones INTEGER DEFAULT 0,
    
    -- Sync status at checkpoint
    usuarios_sincronizados INTEGER DEFAULT 0,
    credenciales_sincronizadas INTEGER DEFAULT 0,
    textos_sincronizados INTEGER DEFAULT 0,
    
    -- Hashes for integrity
    hash_usuarios VARCHAR(64),
    hash_credenciales VARCHAR(64),
    hash_textos VARCHAR(64),
    hash_global VARCHAR(64),
    
    -- Metadata
    notas TEXT,
    tipo_checkpoint VARCHAR(50) DEFAULT 'automatico', -- 'automatico', 'manual', 'programado'
    
    CONSTRAINT unique_checkpoint UNIQUE (id_usuario, dispositivo_id, nombre_checkpoint)
);

CREATE INDEX idx_checkpoint_usuario_dispositivo ON checkpoints_sincronizacion(id_usuario, dispositivo_id);
CREATE INDEX idx_checkpoint_timestamp ON checkpoints_sincronizacion(timestamp_checkpoint DESC);

COMMENT ON TABLE checkpoints_sincronizacion IS 'Snapshots of sync state at specific points in time for rollback and verification';


-- ============================================
-- 7. CREATE FUNCTION TO MARK AS SYNCED
-- ============================================

CREATE OR REPLACE FUNCTION marcar_como_sincronizado(
    p_entidad VARCHAR(50),
    p_id_entidad INTEGER,
    p_dispositivo_id VARCHAR(100)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_hash VARCHAR(64);
    v_updated BOOLEAN := FALSE;
BEGIN
    -- Generate hash based on current timestamp and entity
    v_hash := encode(digest(p_entidad || p_id_entidad || NOW()::TEXT, 'sha256'), 'hex');
    
    -- Update the appropriate table
    IF p_entidad = 'usuarios' THEN
        UPDATE usuarios
        SET 
            sincronizado = TRUE,
            fecha_sincronizacion = NOW(),
            hash_sincronizacion = v_hash,
            version_sincronizacion = version_sincronizacion + 1
        WHERE id_usuario = p_id_entidad;
        
        v_updated := FOUND;
        
    ELSIF p_entidad = 'credenciales_biometricas' THEN
        UPDATE credenciales_biometricas
        SET 
            sincronizado = TRUE,
            fecha_sincronizacion = NOW(),
            hash_sincronizacion = v_hash,
            version_sincronizacion = version_sincronizacion + 1,
            dispositivos_sincronizados = array_append(
                COALESCE(dispositivos_sincronizados, ARRAY[]::TEXT[]),
                p_dispositivo_id
            )
        WHERE id_credencial = p_id_entidad
        AND NOT (p_dispositivo_id = ANY(COALESCE(dispositivos_sincronizados, ARRAY[]::TEXT[])));
        
        v_updated := FOUND;
        
    ELSIF p_entidad = 'textos_dinamicos_audio' THEN
        UPDATE textos_dinamicos_audio
        SET 
            sincronizado = TRUE,
            fecha_sincronizacion = NOW(),
            dispositivos_sincronizados = array_append(
                COALESCE(dispositivos_sincronizados, ARRAY[]::TEXT[]),
                p_dispositivo_id
            )
        WHERE id_texto = p_id_entidad
        AND NOT (p_dispositivo_id = ANY(COALESCE(dispositivos_sincronizados, ARRAY[]::TEXT[])));
        
        v_updated := FOUND;
    END IF;
    
    -- Update metadata
    IF v_updated THEN
        INSERT INTO metadata_sincronizacion (
            id_usuario, dispositivo_id, entidad, id_entidad,
            estado_sync, direccion, fecha_sincronizacion,
            version_local, hash_local
        ) VALUES (
            (SELECT id_usuario FROM usuarios WHERE id_usuario = p_id_entidad LIMIT 1),
            p_dispositivo_id,
            p_entidad,
            p_id_entidad,
            'sincronizado',
            'servidor_a_dispositivo',
            NOW(),
            1,
            v_hash
        )
        ON CONFLICT (id_usuario, dispositivo_id, entidad, id_entidad)
        DO UPDATE SET
            estado_sync = 'sincronizado',
            fecha_sincronizacion = NOW(),
            fecha_modificacion = NOW(),
            hash_local = v_hash,
            version_local = metadata_sincronizacion.version_local + 1;
    END IF;
    
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION marcar_como_sincronizado IS 'Marks an entity as synchronized and updates metadata';


-- ============================================
-- 8. CREATE FUNCTION TO GET PENDING SYNC ITEMS
-- ============================================

CREATE OR REPLACE FUNCTION obtener_pendientes_sincronizacion(
    p_id_usuario INTEGER,
    p_dispositivo_id VARCHAR(100),
    p_entidad VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE (
    entidad VARCHAR(50),
    id_entidad INTEGER,
    fecha_modificacion TIMESTAMP,
    sincronizado BOOLEAN,
    version INTEGER
) AS $$
BEGIN
    -- If entidad is specified, return only that entity type
    -- Otherwise return all pending items
    
    IF p_entidad = 'usuarios' OR p_entidad IS NULL THEN
        RETURN QUERY
        SELECT 
            'usuarios'::VARCHAR(50) AS entidad,
            u.id_usuario AS id_entidad,
            u.fecha_actualizacion AS fecha_modificacion,
            u.sincronizado,
            u.version_sincronizacion AS version
        FROM usuarios u
        WHERE u.id_usuario = p_id_usuario
        AND (u.sincronizado = FALSE OR u.sincronizado IS NULL);
    END IF;
    
    IF p_entidad = 'credenciales_biometricas' OR p_entidad IS NULL THEN
        RETURN QUERY
        SELECT 
            'credenciales_biometricas'::VARCHAR(50) AS entidad,
            c.id_credencial AS id_entidad,
            c.fecha_registro AS fecha_modificacion,
            c.sincronizado,
            c.version_sincronizacion AS version
        FROM credenciales_biometricas c
        WHERE c.id_usuario = p_id_usuario
        AND (c.sincronizado = FALSE OR c.sincronizado IS NULL)
        AND NOT (p_dispositivo_id = ANY(COALESCE(c.dispositivos_sincronizados, ARRAY[]::TEXT[])));
    END IF;
    
    IF p_entidad = 'textos_dinamicos_audio' OR p_entidad IS NULL THEN
        RETURN QUERY
        SELECT 
            'textos_dinamicos_audio'::VARCHAR(50) AS entidad,
            t.id_texto AS id_entidad,
            t.fecha_asignacion AS fecha_modificacion,
            t.sincronizado,
            1 AS version
        FROM textos_dinamicos_audio t
        WHERE t.id_usuario = p_id_usuario
        AND (t.sincronizado = FALSE OR t.sincronizado IS NULL)
        AND NOT (p_dispositivo_id = ANY(COALESCE(t.dispositivos_sincronizados, ARRAY[]::TEXT[])));
    END IF;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION obtener_pendientes_sincronizacion IS 'Returns all items pending synchronization for a user and device';


-- ============================================
-- 9. CREATE FUNCTION TO CREATE CHECKPOINT
-- ============================================

CREATE OR REPLACE FUNCTION crear_checkpoint_sincronizacion(
    p_id_usuario INTEGER,
    p_dispositivo_id VARCHAR(100),
    p_nombre_checkpoint VARCHAR(100) DEFAULT NULL,
    p_notas TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_id_checkpoint INTEGER;
    v_nombre VARCHAR(100);
    v_hash_global VARCHAR(64);
BEGIN
    -- Generate checkpoint name if not provided
    IF p_nombre_checkpoint IS NULL THEN
        v_nombre := 'checkpoint_' || TO_CHAR(NOW(), 'YYYYMMDD_HH24MISS');
    ELSE
        v_nombre := p_nombre_checkpoint;
    END IF;
    
    -- Generate global hash
    v_hash_global := encode(digest(
        p_id_usuario::TEXT || p_dispositivo_id || NOW()::TEXT, 
        'sha256'
    ), 'hex');
    
    -- Insert checkpoint
    INSERT INTO checkpoints_sincronizacion (
        id_usuario,
        dispositivo_id,
        nombre_checkpoint,
        timestamp_checkpoint,
        total_usuarios,
        total_credenciales,
        total_textos,
        usuarios_sincronizados,
        credenciales_sincronizadas,
        textos_sincronizados,
        hash_global,
        notas,
        tipo_checkpoint
    )
    SELECT 
        p_id_usuario,
        p_dispositivo_id,
        v_nombre,
        NOW(),
        (SELECT COUNT(*) FROM usuarios WHERE id_usuario = p_id_usuario),
        (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = p_id_usuario),
        (SELECT COUNT(*) FROM textos_dinamicos_audio WHERE id_usuario = p_id_usuario),
        (SELECT COUNT(*) FROM usuarios WHERE id_usuario = p_id_usuario AND sincronizado = TRUE),
        (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = p_id_usuario AND sincronizado = TRUE),
        (SELECT COUNT(*) FROM textos_dinamicos_audio WHERE id_usuario = p_id_usuario AND sincronizado = TRUE),
        v_hash_global,
        p_notas,
        CASE WHEN p_nombre_checkpoint IS NULL THEN 'automatico' ELSE 'manual' END
    RETURNING id_checkpoint INTO v_id_checkpoint;
    
    RETURN v_id_checkpoint;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION crear_checkpoint_sincronizacion IS 'Creates a snapshot of current sync state for rollback and verification';


-- ============================================
-- 10. CREATE VIEW FOR SYNC STATUS
-- ============================================

CREATE OR REPLACE VIEW vista_estado_sincronizacion AS
SELECT 
    u.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    u.identificador_unico,
    
    -- User sync status
    u.sincronizado AS usuario_sincronizado,
    u.fecha_sincronizacion AS usuario_fecha_sync,
    u.version_sincronizacion AS usuario_version,
    
    -- Credentials count
    (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = u.id_usuario) AS total_credenciales,
    (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = u.id_usuario AND sincronizado = TRUE) AS credenciales_sincronizadas,
    
    -- Dynamic texts count
    (SELECT COUNT(*) FROM textos_dinamicos_audio WHERE id_usuario = u.id_usuario) AS total_textos,
    (SELECT COUNT(*) FROM textos_dinamicos_audio WHERE id_usuario = u.id_usuario AND sincronizado = TRUE) AS textos_sincronizados,
    
    -- Sync percentage
    CASE 
        WHEN (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = u.id_usuario) = 0 THEN 100
        ELSE ROUND(
            (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = u.id_usuario AND sincronizado = TRUE)::DECIMAL * 100 /
            (SELECT COUNT(*) FROM credenciales_biometricas WHERE id_usuario = u.id_usuario)::DECIMAL,
            2
        )
    END AS porcentaje_sincronizacion,
    
    -- Last sync info
    (SELECT MAX(fecha_sincronizacion) FROM sincronizaciones WHERE id_usuario = u.id_usuario) AS ultima_sincronizacion,
    (SELECT COUNT(*) FROM metadata_sincronizacion WHERE id_usuario = u.id_usuario AND tiene_conflicto = TRUE) AS conflictos_pendientes
    
FROM usuarios u
ORDER BY u.id_usuario;

COMMENT ON VIEW vista_estado_sincronizacion IS 'Overview of synchronization status for all users';


-- ============================================
-- 11. CREATE TRIGGER TO AUTO-MARK AS PENDING
-- ============================================

CREATE OR REPLACE FUNCTION marcar_como_pendiente_sync()
RETURNS TRIGGER AS $$
BEGIN
    -- Mark as not synced when data is modified
    IF TG_OP = 'UPDATE' THEN
        NEW.sincronizado := FALSE;
        NEW.fecha_sincronizacion := NULL;
        NEW.version_sincronizacion := COALESCE(NEW.version_sincronizacion, 0) + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to usuarios
DROP TRIGGER IF EXISTS trigger_usuarios_sync_pending ON usuarios;
CREATE TRIGGER trigger_usuarios_sync_pending
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    WHEN (
        OLD.nombres IS DISTINCT FROM NEW.nombres OR
        OLD.apellidos IS DISTINCT FROM NEW.apellidos OR
        OLD.identificador_unico IS DISTINCT FROM NEW.identificador_unico
    )
    EXECUTE FUNCTION marcar_como_pendiente_sync();

-- Apply trigger to credenciales_biometricas
DROP TRIGGER IF EXISTS trigger_credenciales_sync_pending ON credenciales_biometricas;
CREATE TRIGGER trigger_credenciales_sync_pending
    BEFORE UPDATE ON credenciales_biometricas
    FOR EACH ROW
    WHEN (
        OLD.datos_biometricos IS DISTINCT FROM NEW.datos_biometricos OR
        OLD.activa IS DISTINCT FROM NEW.activa
    )
    EXECUTE FUNCTION marcar_como_pendiente_sync();

COMMENT ON FUNCTION marcar_como_pendiente_sync IS 'Automatically marks records as pending sync when modified';


-- =====================================================
-- END OF MIGRATION 007
-- =====================================================
