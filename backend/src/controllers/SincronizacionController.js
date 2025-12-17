const pool = require('../config/database');
const crypto = require('crypto');

class SincronizacionController {
  // Obtener datos para sincronización descendente (Backend → App)
  static async obtenerDatosDescarga(req, res) {
    try {
      const { id_usuario } = req.user;
      const { ultima_sync, dispositivo_id } = req.body;

      // Obtener usuarios actualizados desde última sincronización
      const usuariosQuery = `
        SELECT id_usuario, nombres, apellidos, identificador_unico, estado
        FROM usuarios
        WHERE id_usuario = $1 OR estado = 'activo'
        ORDER BY fecha_registro DESC
      `;

      // Obtener templates vigentes
      const templatesQuery = `
        SELECT id_credencial, tipo_biometria, version_algoritmo, 
               validez_hasta, estado, hash_integridad
        FROM credenciales_biometricas
        WHERE id_usuario = $1 AND estado = 'activo'
        AND (validez_hasta IS NULL OR validez_hasta > CURRENT_DATE)
      `;

      // Obtener frases dinámicas vigentes
      const frasesQuery = `
        SELECT id_texto, frase, estado_texto
        FROM textos_dinamicos_audio
        WHERE id_usuario = $1 AND estado_texto = 'activo'
      `;

      const [usuariosResult, templatesResult, frasesResult] = await Promise.all([
        pool.query(usuariosQuery, [id_usuario]),
        pool.query(templatesQuery, [id_usuario]),
        pool.query(frasesQuery, [id_usuario])
      ]);

      // Registrar sincronización
      await pool.query(
        `INSERT INTO sincronizaciones (
          id_usuario, dispositivo_id, tipo_sync, estado_sync, cantidad_items
        ) VALUES ($1, $2, $3, $4, $5)`,
        [id_usuario, dispositivo_id, 'recepcion', 'completo',
         usuariosResult.rows.length + templatesResult.rows.length + frasesResult.rows.length]
      );

      res.json({
        success: true,
        timestamp: new Date().toISOString(),
        datos: {
          usuarios: usuariosResult.rows,
          credenciales_biometricas: templatesResult.rows,
          textos_audio: frasesResult.rows
        }
      });
    } catch (error) {
      console.error('Error en descarga de sincronización:', error);
      res.status(500).json({
        success: false,
        error: 'Error en sincronización',
        codigo: error.code
      });
    }
  }

  // Recibir datos de sincronización ascendente (App → Backend)
  static async recibirDatosSubida(req, res) {
    try {
      // Obtener id_usuario del token si existe (usuario autenticado)
      // O null si es registro offline (sin autenticación)
      const id_usuario = req.user?.id_usuario || null;
      const { dispositivo_id, validaciones, eventos, creaciones } = req.body;

      if (!dispositivo_id) {
        return res.status(400).json({
          success: false,
          error: 'dispositivo_id es requerido'
        });
      }

      let exitosas = 0;
      let errores = [];
      const mappings = [];

      // Procesar creaciones (usuarios, credenciales, etc.)
      if (Array.isArray(creaciones)) {
        for (const item of creaciones) {
          try {
            const tipo = item.tipo_entidad;
            const datos = item.datos || {};
            const localUuid = item.local_uuid || null;
            const idCola = item.id_cola || null;

            if (tipo === 'usuario') {
              const insertRes = await pool.query(
                `INSERT INTO usuarios (nombres, apellidos, identificador_unico, estado)
                 VALUES ($1, $2, $3, $4) RETURNING id_usuario`,
                [
                  datos.nombres || null,
                  datos.apellidos || null,
                  datos.identificador_unico || null,
                  datos.estado || 'activo'
                ]
              );

              const newId = insertRes.rows[0].id_usuario;
              mappings.push({
                local_uuid: localUuid,
                entidad: 'usuario',
                remote_id: newId,
                id_cola: idCola,
              });
              exitosas++;
            } else if (tipo === 'credencial' || tipo === 'credencial_biometrica') {
              // Usar id_usuario remoto si viene, si no usar el del token/sesión
              const idUsuarioRemoto = datos.id_usuario_remote || id_usuario;
              
              if (!idUsuarioRemoto) {
                errores.push({
                  item,
                  error: 'id_usuario no disponible para insertar credencial'
                });
                continue;
              }

              const resInsert = await pool.query(
                `INSERT INTO credenciales_biometricas (
                  id_usuario, tipo_biometria, template, validez_hasta, version_algoritmo, hash_integridad, estado
                ) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id_credencial`,
                [
                  idUsuarioRemoto,
                  datos.tipo_biometria || null,
                  datos.template || null,
                  datos.validez_hasta || null,
                  datos.version_algoritmo || null,
                  datos.hash_integridad || null,
                  datos.estado || 'activo'
                ]
              );

              const newCredId = resInsert.rows[0].id_credencial;
              mappings.push({
                local_uuid: localUuid,
                entidad: 'credencial',
                remote_id: newCredId,
                id_cola: idCola,
              });
              exitosas++;
            } else {
              // Otros tipos pueden ser tratados aquí
            }
          } catch (error) {
            errores.push({ item, error: error.message });
          }
        }
      }

      // Procesar validaciones (solo si tenemos id_usuario)
      if (Array.isArray(validaciones) && id_usuario) {
        for (const validacion of validaciones) {
          try {
            await pool.query(
              `INSERT INTO validaciones_biometricas (
                id_usuario, tipo_biometria, resultado, modo_validacion,
                dispositivo_id, puntuacion_confianza, ubicacion_gps
              ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
              [
                id_usuario,
                validacion.tipo_biometria,
                validacion.resultado,
                validacion.modo_validacion || 'offline',
                dispositivo_id,
                validacion.puntuacion_confianza || 0,
                validacion.ubicacion_gps || null
              ]
            );
            exitosas++;
          } catch (error) {
            errores.push({
              validacion,
              error: error.message
            });
          }
        }
      }

      // Registrar sincronización (PERMITIR id_usuario NULL para registro offline)
      const syncQuery = `
        INSERT INTO sincronizaciones (
          id_usuario, dispositivo_id, tipo_sync, estado_sync, cantidad_items
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id_sync
      `;
      
      const syncResult = await pool.query(
        syncQuery,
        [id_usuario, dispositivo_id, 'envio',
         errores.length === 0 ? 'completo' : 'error',
         exitosas]
      );

      res.json({
        success: true,
        id_sync: syncResult.rows[0]?.id_sync,
        exitosas,
        errores: errores.length > 0 ? errores : undefined,
        mappings: mappings,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      console.error('Error en subida de sincronización:', error);
      res.status(500).json({
        success: false,
        error: 'Error en sincronización',
        detalles: error.message
      });
    }
  }

  // Obtener estado de sincronización
  static async obtenerEstadoSync(req, res) {
    try {
      const { id_usuario } = req.user;

      const query = `
        SELECT 
          id_sync, fecha_ultima_sync, estado_sync, cantidad_items,
          tipo_sync, codigo_error
        FROM sincronizaciones
        WHERE id_usuario = $1
        ORDER BY fecha_ultima_sync DESC
        LIMIT 10
      `;

      const result = await pool.query(query, [id_usuario]);

      res.json({
        success: true,
        sincronizaciones: result.rows
      });
    } catch (error) {
      console.error('Error al obtener estado:', error);
      res.status(500).json({
        success: false,
        error: 'Error al obtener estado'
      });
    }
  }

  // Reintentar sincronización fallida
  static async reintentarSync(req, res) {
    try {
      const { id_usuario } = req.user;
      const { id_sync } = req.params;

      // Obtener sincronización
      const result = await pool.query(
        'SELECT * FROM sincronizaciones WHERE id_sync = $1 AND id_usuario = $2',
        [id_sync, id_usuario]
      );

      if (result.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: 'Sincronización no encontrada'
        });
      }

      // Marcar para reintento
      await pool.query(
        'UPDATE sincronizaciones SET estado_sync = $1, fecha_ultima_sync = CURRENT_TIMESTAMP WHERE id_sync = $2',
        ['pendiente', id_sync]
      );

      res.json({
        success: true,
        mensaje: 'Reintento programado'
      });
    } catch (error) {
      console.error('Error en reintento:', error);
      res.status(500).json({
        success: false,
        error: 'Error en reintento'
      });
    }
  }

  // Ping/Verificación de disponibilidad
  static async ping(req, res) {
    try {
      res.json({
        success: true,
        timestamp: new Date().toISOString(),
        servidor: 'disponible',
        version_api: '1.0.0'
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: 'Error en ping'
      });
    }
  }

  // Obtener cola de sincronización pendiente
  static async obtenerColaPendiente(req, res) {
    try {
      const { id_usuario } = req.user;

      const query = `
        SELECT id_cola, tipo_entidad, operacion, datos_json, 
               intentos_envio, proximo_reintento
        FROM cola_sincronizacion
        WHERE id_usuario = $1 AND estado = 'pendiente'
        ORDER BY fecha_creacion ASC
        LIMIT 100
      `;

      const result = await pool.query(query, [id_usuario]);

      res.json({
        success: true,
        cola: result.rows,
        pendientes: result.rows.length
      });
    } catch (error) {
      console.error('Error al obtener cola:', error);
      res.status(500).json({
        success: false,
        error: 'Error al obtener cola'
      });
    }
  }

  // Confirmar elementos sincronizados
  static async confirmarSync(req, res) {
    try {
      const { id_usuario } = req.user;
      const { ids_cola } = req.body;

      if (!Array.isArray(ids_cola)) {
        return res.status(400).json({
          success: false,
          error: 'ids_cola debe ser un array'
        });
      }

      for (const id_cola of ids_cola) {
        await pool.query(
          'UPDATE cola_sincronizacion SET estado = $1 WHERE id_cola = $2 AND id_usuario = $3',
          ['enviado', id_cola, id_usuario]
        );
      }

      res.json({
        success: true,
        confirmados: ids_cola.length
      });
    } catch (error) {
      console.error('Error en confirmación:', error);
      res.status(500).json({
        success: false,
        error: 'Error en confirmación'
      });
    }
  }
}

module.exports = SincronizacionController;
