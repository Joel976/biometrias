-- =====================================================
-- FIX FOR MIGRATION 007: SYNC FLAGS CORRECTIONS
-- =====================================================

-- Fix the view with proper GROUP BY
CREATE OR REPLACE VIEW vista_estado_sincronizacion AS
SELECT 
    u.id_usuario,
    u.nombres || ' ' || u.apellidos AS nombre_completo,
    u.identificador_unico,
    u.sincronizado AS usuario_sincronizado,
    u.fecha_sincronizacion AS usuario_fecha_sync,
    u.version_sincronizacion AS usuario_version,
    COUNT(DISTINCT c.id_credencial) AS total_credenciales,
    COUNT(DISTINCT CASE WHEN c.sincronizado = TRUE THEN c.id_credencial END) AS credenciales_sincronizadas,
    COUNT(DISTINCT t.id_texto) AS total_textos,
    COUNT(DISTINCT CASE WHEN t.sincronizado = TRUE THEN t.id_texto END) AS textos_sincronizados,
    CASE 
        WHEN COUNT(DISTINCT c.id_credencial) = 0 THEN 100
        ELSE ROUND(
            COUNT(DISTINCT CASE WHEN c.sincronizado = TRUE THEN c.id_credencial END)::DECIMAL * 100 /
            NULLIF(COUNT(DISTINCT c.id_credencial), 0)::DECIMAL,
            2
        )
    END AS porcentaje_sincronizacion,
    MAX(s.fecha_sincronizacion) AS ultima_sincronizacion,
    COUNT(DISTINCT CASE WHEN m.tiene_conflicto = TRUE THEN m.id_metadata END) AS conflictos_pendientes
FROM usuarios u
LEFT JOIN credenciales_biometricas c ON u.id_usuario = c.id_usuario
LEFT JOIN textos_dinamicos_audio t ON u.id_usuario = t.id_usuario
LEFT JOIN sincronizaciones s ON u.id_usuario = s.id_usuario
LEFT JOIN metadata_sincronizacion m ON u.id_usuario = m.id_usuario
GROUP BY u.id_usuario, u.nombres, u.apellidos, u.identificador_unico, 
         u.sincronizado, u.fecha_sincronizacion, u.version_sincronizacion
ORDER BY u.id_usuario;

-- Fix the trigger for credenciales_biometricas (use 'template' instead of 'datos_biometricos')
DROP TRIGGER IF EXISTS trigger_credenciales_sync_pending ON credenciales_biometricas;

CREATE TRIGGER trigger_credenciales_sync_pending
    BEFORE UPDATE ON credenciales_biometricas
    FOR EACH ROW
    WHEN (
        OLD.template IS DISTINCT FROM NEW.template OR
        OLD.estado IS DISTINCT FROM NEW.estado
    )
    EXECUTE FUNCTION marcar_como_pendiente_sync();

COMMENT ON VIEW vista_estado_sincronizacion IS 'Overview of synchronization status for all users (corrected)';
