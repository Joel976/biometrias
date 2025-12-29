/**
 * =====================================================
 * SERVICIO DE BANDERAS DE SINCRONIZACION
 * Sistema de Autenticacion Biometrica
 * =====================================================
 */

const { pool } = require('../config/database');
const crypto = require('crypto');

class SyncFlagsService {
  /**
   * Marcar entidad como sincronizada
   * @param {string} entidad - 'usuarios', 'credenciales_biometricas', 'textos_dinamicos_audio'
   * @param {number} idEntidad - ID de la entidad
   * @param {string} dispositivoId - ID del dispositivo
   */
  static async marcarComoSincronizado(entidad, idEntidad, dispositivoId) {
    try {
      const query = 'SELECT marcar_como_sincronizado($1, $2, $3)';
      const resultado = await pool.query(query, [entidad, idEntidad, dispositivoId]);
      
      const exitoso = resultado.rows[0].marcar_como_sincronizado;
      
      if (exitoso) {
        console.log(`[SYNC FLAGS] ✅ ${entidad} ${idEntidad} marcado como sincronizado para dispositivo ${dispositivoId}`);
      } else {
        console.warn(`[SYNC FLAGS] ⚠️ No se pudo marcar ${entidad} ${idEntidad}`);
      }
      
      return exitoso;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error marcando como sincronizado:`, error);
      return false;
    }
  }

  /**
   * Marcar múltiples entidades como sincronizadas
   * @param {Array} items - [{entidad, idEntidad}]
   * @param {string} dispositivoId
   */
  static async marcarLoteComoSincronizado(items, dispositivoId) {
    const resultados = {
      exitosos: 0,
      fallidos: 0,
      detalles: []
    };

    for (const item of items) {
      const exitoso = await this.marcarComoSincronizado(
        item.entidad,
        item.idEntidad,
        dispositivoId
      );
      
      if (exitoso) {
        resultados.exitosos++;
      } else {
        resultados.fallidos++;
      }
      
      resultados.detalles.push({
        ...item,
        sincronizado: exitoso
      });
    }

    console.log(`[SYNC FLAGS] Lote completado: ${resultados.exitosos} exitosos, ${resultados.fallidos} fallidos`);
    
    return resultados;
  }

  /**
   * Obtener elementos pendientes de sincronizacion
   * @param {number} idUsuario
   * @param {string} dispositivoId
   * @param {string} entidad - Opcional, filtra por tipo de entidad
   */
  static async obtenerPendientesSincronizacion(idUsuario, dispositivoId, entidad = null) {
    try {
      const query = 'SELECT * FROM obtener_pendientes_sincronizacion($1, $2, $3)';
      const resultado = await pool.query(query, [idUsuario, dispositivoId, entidad]);
      
      console.log(`[SYNC FLAGS] ${resultado.rows.length} elementos pendientes para usuario ${idUsuario}`);
      
      return resultado.rows;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo pendientes:`, error);
      return [];
    }
  }

  /**
   * Crear checkpoint de sincronizacion
   * @param {number} idUsuario
   * @param {string} dispositivoId
   * @param {string} nombreCheckpoint - Opcional
   * @param {string} notas - Opcional
   */
  static async crearCheckpoint(idUsuario, dispositivoId, nombreCheckpoint = null, notas = null) {
    try {
      const query = 'SELECT crear_checkpoint_sincronizacion($1, $2, $3, $4)';
      const resultado = await pool.query(query, [
        idUsuario,
        dispositivoId,
        nombreCheckpoint,
        notas
      ]);
      
      const idCheckpoint = resultado.rows[0].crear_checkpoint_sincronizacion;
      
      console.log(`[SYNC FLAGS] ✅ Checkpoint creado: ${idCheckpoint}`);
      
      return idCheckpoint;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error creando checkpoint:`, error);
      return null;
    }
  }

  /**
   * Obtener estado de sincronizacion de un usuario
   * @param {number} idUsuario
   */
  static async obtenerEstadoSincronizacion(idUsuario) {
    try {
      const query = `
        SELECT * FROM vista_estado_sincronizacion
        WHERE id_usuario = $1
      `;
      const resultado = await pool.query(query, [idUsuario]);
      
      return resultado.rows[0] || null;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo estado:`, error);
      return null;
    }
  }

  /**
   * Obtener todos los estados de sincronizacion
   */
  static async obtenerTodosLosEstados() {
    try {
      const query = 'SELECT * FROM vista_estado_sincronizacion ORDER BY id_usuario';
      const resultado = await pool.query(query);
      
      return resultado.rows;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo estados:`, error);
      return [];
    }
  }

  /**
   * Obtener metadata de sincronizacion
   * @param {number} idUsuario
   * @param {string} dispositivoId
   * @param {string} estadoSync - Opcional: 'pendiente', 'sincronizado', 'conflicto', 'error'
   */
  static async obtenerMetadataSincronizacion(idUsuario, dispositivoId, estadoSync = null) {
    try {
      let query = `
        SELECT * FROM metadata_sincronizacion
        WHERE id_usuario = $1 AND dispositivo_id = $2
      `;
      const params = [idUsuario, dispositivoId];
      
      if (estadoSync) {
        query += ' AND estado_sync = $3';
        params.push(estadoSync);
      }
      
      query += ' ORDER BY fecha_modificacion DESC';
      
      const resultado = await pool.query(query, params);
      
      return resultado.rows;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo metadata:`, error);
      return [];
    }
  }

  /**
   * Obtener conflictos de sincronizacion
   * @param {number} idUsuario
   * @param {string} dispositivoId
   */
  static async obtenerConflictos(idUsuario, dispositivoId = null) {
    try {
      let query = `
        SELECT * FROM metadata_sincronizacion
        WHERE tiene_conflicto = TRUE
      `;
      const params = [];
      
      if (idUsuario) {
        query += ' AND id_usuario = $1';
        params.push(idUsuario);
      }
      
      if (dispositivoId) {
        query += ` AND dispositivo_id = $${params.length + 1}`;
        params.push(dispositivoId);
      }
      
      query += ' ORDER BY fecha_modificacion DESC';
      
      const resultado = await pool.query(query, params);
      
      return resultado.rows;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo conflictos:`, error);
      return [];
    }
  }

  /**
   * Resolver conflicto de sincronizacion
   * @param {number} idMetadata
   * @param {string} resolucion - 'servidor_gana', 'dispositivo_gana', 'manual', 'merge'
   */
  static async resolverConflicto(idMetadata, resolucion) {
    try {
      const query = `
        UPDATE metadata_sincronizacion
        SET 
          tiene_conflicto = FALSE,
          resolucion_conflicto = $1,
          fecha_modificacion = NOW()
        WHERE id_metadata = $2
        RETURNING *
      `;
      
      const resultado = await pool.query(query, [resolucion, idMetadata]);
      
      if (resultado.rows.length > 0) {
        console.log(`[SYNC FLAGS] ✅ Conflicto ${idMetadata} resuelto: ${resolucion}`);
        return resultado.rows[0];
      }
      
      return null;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error resolviendo conflicto:`, error);
      return null;
    }
  }

  /**
   * Obtener checkpoints de un usuario
   * @param {number} idUsuario
   * @param {string} dispositivoId
   * @param {number} limite
   */
  static async obtenerCheckpoints(idUsuario, dispositivoId, limite = 10) {
    try {
      const query = `
        SELECT * FROM checkpoints_sincronizacion
        WHERE id_usuario = $1 AND dispositivo_id = $2
        ORDER BY timestamp_checkpoint DESC
        LIMIT $3
      `;
      
      const resultado = await pool.query(query, [idUsuario, dispositivoId, limite]);
      
      return resultado.rows;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error obteniendo checkpoints:`, error);
      return [];
    }
  }

  /**
   * Registrar intento de sincronizacion
   * @param {Object} datos - Datos del intento
   */
  static async registrarIntentoSincronizacion(datos) {
    const {
      idUsuario,
      dispositivoId,
      tipoSincronizacion,
      direccion,
      cantidadRegistros = 0,
      tamanoKb = 0,
      duracionMs = 0,
      exitoso = true,
      error = null
    } = datos;

    try {
      const query = `
        INSERT INTO sincronizaciones (
          id_usuario, dispositivo_id, tipo_sincronizacion, direccion,
          fecha_ultima_sync, estado_sync, cantidad_registros_enviados,
          tamano_datos_kb, duracion_ms
        ) VALUES ($1, $2, $3, $4, NOW(), $5, $6, $7, $8)
        RETURNING id_sync
      `;
      
      const resultado = await pool.query(query, [
        idUsuario,
        dispositivoId,
        tipoSincronizacion,
        direccion,
        exitoso ? 'completado' : 'error',
        cantidadRegistros,
        tamanoKb,
        duracionMs
      ]);
      
      const idSync = resultado.rows[0].id_sync;
      
      // Si hubo error, registrarlo
      if (!exitoso && error) {
        await pool.query(`
          INSERT INTO errores_sync (
            id_usuario, dispositivo_id, tipo_error, mensaje_error, timestamp
          ) VALUES ($1, $2, $3, $4, NOW())
        `, [idUsuario, dispositivoId, 'sync_failed', error]);
      }
      
      console.log(`[SYNC FLAGS] Intento de sync registrado: ${idSync} (${exitoso ? 'exitoso' : 'error'})`);
      
      return idSync;
    } catch (error) {
      console.error(`[SYNC FLAGS] Error registrando intento:`, error);
      return null;
    }
  }

  /**
   * Calcular hash de datos para verificacion de integridad
   * @param {Object} datos
   */
  static calcularHash(datos) {
    const json = JSON.stringify(datos);
    return crypto.createHash('sha256').update(json).digest('hex');
  }

  /**
   * Verificar integridad de datos sincronizados
   * @param {string} entidad
   * @param {number} idEntidad
   * @param {string} hashEsperado
   */
  static async verificarIntegridad(entidad, idEntidad, hashEsperado) {
    try {
      let query;
      
      if (entidad === 'usuarios') {
        query = `SELECT hash_sincronizacion FROM usuarios WHERE id_usuario = $1`;
      } else if (entidad === 'credenciales_biometricas') {
        query = `SELECT hash_sincronizacion FROM credenciales_biometricas WHERE id_credencial = $1`;
      } else {
        return { valido: false, error: 'Entidad no soportada' };
      }
      
      const resultado = await pool.query(query, [idEntidad]);
      
      if (resultado.rows.length === 0) {
        return { valido: false, error: 'Entidad no encontrada' };
      }
      
      const hashActual = resultado.rows[0].hash_sincronizacion;
      const valido = hashActual === hashEsperado;
      
      return {
        valido,
        hashActual,
        hashEsperado,
        coincide: valido
      };
    } catch (error) {
      console.error(`[SYNC FLAGS] Error verificando integridad:`, error);
      return { valido: false, error: error.message };
    }
  }

  /**
   * Limpiar banderas de dispositivos que no existen
   * @param {number} idUsuario
   * @param {Array<string>} dispositivosActivos
   */
  static async limpiarDispositivosInactivos(idUsuario, dispositivosActivos) {
    try {
      // Obtener todos los dispositivos registrados para el usuario
      const queryDispositivos = `
        SELECT DISTINCT dispositivo_id 
        FROM metadata_sincronizacion 
        WHERE id_usuario = $1
      `;
      const dispositivos = await pool.query(queryDispositivos, [idUsuario]);
      
      const dispositivosInactivos = dispositivos.rows
        .map(row => row.dispositivo_id)
        .filter(id => !dispositivosActivos.includes(id));
      
      if (dispositivosInactivos.length === 0) {
        return { eliminados: 0, dispositivos: [] };
      }
      
      // Eliminar metadata de dispositivos inactivos
      const queryEliminar = `
        DELETE FROM metadata_sincronizacion
        WHERE id_usuario = $1 AND dispositivo_id = ANY($2)
      `;
      await pool.query(queryEliminar, [idUsuario, dispositivosInactivos]);
      
      console.log(`[SYNC FLAGS] Limpieza: ${dispositivosInactivos.length} dispositivos inactivos`);
      
      return {
        eliminados: dispositivosInactivos.length,
        dispositivos: dispositivosInactivos
      };
    } catch (error) {
      console.error(`[SYNC FLAGS] Error limpiando dispositivos:`, error);
      return { eliminados: 0, dispositivos: [], error: error.message };
    }
  }
}

module.exports = SyncFlagsService;
