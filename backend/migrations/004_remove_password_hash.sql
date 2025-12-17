-- Migración 004: Eliminar columna password_hash de usuarios (si existe)
-- Fecha: 2025-12-01

ALTER TABLE usuarios
DROP COLUMN IF EXISTS password_hash;

-- Mensaje de confirmación
SELECT 'Migración 004 completada: password_hash eliminada (si existía)' AS status;
