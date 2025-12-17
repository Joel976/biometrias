-- Limpiar tablas en PostgreSQL (backend)
-- CUIDADO: Esto BORRA todos los datos

-- Vaciar tablas (mantener estructura)
TRUNCATE TABLE validaciones_biometricas CASCADE;
TRUNCATE TABLE sesiones CASCADE;
TRUNCATE TABLE credenciales_biometricas CASCADE;
TRUNCATE TABLE usuarios CASCADE;

-- Resetear secuencias de auto-increment
ALTER SEQUENCE usuarios_id_usuario_seq RESTART WITH 1;
ALTER SEQUENCE credenciales_biometricas_id_credencial_seq RESTART WITH 1;
ALTER SEQUENCE validaciones_biometricas_id_validacion_seq RESTART WITH 1;
ALTER SEQUENCE sesiones_id_sesion_seq RESTART WITH 1;

SELECT 'Bases de datos PostgreSQL limpiadas exitosamente' AS status;
