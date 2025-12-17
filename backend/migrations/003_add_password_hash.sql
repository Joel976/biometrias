-- Migración 003: Agregar columna password_hash a usuarios
-- Fecha: 2024
-- Descripción: Agregar soporte seguro para contraseñas con hash

ALTER TABLE usuarios
ADD COLUMN password_hash VARCHAR(255);

-- Crear índice para búsquedas rápidas por identificador_unico
-- (probablemente ya existe, pero nos aseguramos)
CREATE INDEX IF NOT EXISTS idx_usuarios_identificador_unico
ON usuarios(identificador_unico);

-- Agregar constraint para asegurar que el identificador_unico sea único
ALTER TABLE usuarios
ADD CONSTRAINT uq_usuarios_identificador_unico UNIQUE (identificador_unico);

-- Comentario en la tabla
COMMENT ON COLUMN usuarios.password_hash IS 'Hash PBKDF2-like (SHA-256 x100k) de la contraseña. Formato: "salt$hash"';

-- Salida de confirmación
SELECT 'Migración 003 completada: password_hash agregado a usuarios' AS status;
