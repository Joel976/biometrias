const fs = require('fs');
const path = require('path');
const pool = require('../src/config/database');

// Colores para consola
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

const log = {
  success: (msg) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  warning: (msg) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  info: (msg) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
};

async function runMigrations() {
  try {
    log.info('Iniciando migraciones de base de datos...');

    // Obtener archivo de migraciones
    const migrationsDir = path.join(__dirname);
    const migrationFiles = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql') && file.startsWith('00'))
      .sort();

    if (migrationFiles.length === 0) {
      log.warning('No se encontraron archivos de migración');
      process.exit(0);
    }

    log.info(`Se encontraron ${migrationFiles.length} archivo(s) de migración`);

    // Ejecutar cada migración
    for (const file of migrationFiles) {
      const filePath = path.join(migrationsDir, file);
      log.info(`Ejecutando: ${file}`);

      // Leer archivo SQL
      const sql = fs.readFileSync(filePath, 'utf8');

      // Dividir por puntos y comas (para múltiples comandos)
      const statements = sql
        .split(';')
        .map(stmt => stmt.trim())
        .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

      // Ejecutar cada statement
      for (const statement of statements) {
        try {
          await pool.query(statement);
        } catch (error) {
          // Ignorar errores de "ya existe"
          if (error.code === '42P07' || error.code === '42710') {
            log.warning(`Tabla/índice ya existe (código: ${error.code})`);
          } else if (error.code === '42601') {
            // Error de sintaxis SQL
            log.error(`Error de sintaxis SQL: ${error.message}`);
            throw error;
          } else {
            throw error;
          }
        }
      }

      log.success(`Migración completada: ${file}`);
    }

    log.success('¡Todas las migraciones se ejecutaron exitosamente!');
    process.exit(0);
  } catch (error) {
    log.error(`Error en migraciones: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Ejecutar migraciones
runMigrations();
