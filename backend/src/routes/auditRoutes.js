/**
 * =====================================================
 * RUTAS DE AUDITORIA
 * Sistema de Autenticacion Biometrica
 * =====================================================
 */

const express = require('express');
const router = express.Router();
const { pool } = require('../config/database');
const { AuditoriaService } = require('../middleware/auditoria');
const { verificarToken } = require('../middleware/auth');

/**
 * GET /api/audit/logs
 * Obtener logs de auditoria con filtros
 */
router.get('/logs', verificarToken, async (req, res) => {
  try {
    const {
      id_usuario,
      tipo_accion,
      entidad_afectada,
      fecha_inicio,
      fecha_fin,
      resultado,
      nivel_riesgo,
      limite = 100,
      offset = 0
    } = req.query;

    let query = 'SELECT * FROM logs_auditoria WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (id_usuario) {
      query += ` AND id_usuario = $${paramCount}`;
      params.push(id_usuario);
      paramCount++;
    }

    if (tipo_accion) {
      query += ` AND tipo_accion = $${paramCount}`;
      params.push(tipo_accion);
      paramCount++;
    }

    if (entidad_afectada) {
      query += ` AND entidad_afectada = $${paramCount}`;
      params.push(entidad_afectada);
      paramCount++;
    }

    if (fecha_inicio) {
      query += ` AND timestamp >= $${paramCount}`;
      params.push(fecha_inicio);
      paramCount++;
    }

    if (fecha_fin) {
      query += ` AND timestamp <= $${paramCount}`;
      params.push(fecha_fin);
      paramCount++;
    }

    if (resultado) {
      query += ` AND resultado = $${paramCount}`;
      params.push(resultado);
      paramCount++;
    }

    if (nivel_riesgo) {
      query += ` AND nivel_riesgo = $${paramCount}`;
      params.push(nivel_riesgo);
      paramCount++;
    }

    query += ` ORDER BY timestamp DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
    params.push(limite, offset);

    const resultado_query = await pool.query(query, params);

    // Obtener total de registros
    const countQuery = query.split('ORDER BY')[0].replace('SELECT *', 'SELECT COUNT(*)');
    const countResult = await pool.query(countQuery, params.slice(0, -2));

    res.json({
      exito: true,
      logs: resultado_query.rows,
      total: parseInt(countResult.rows[0].count),
      limite: parseInt(limite),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo logs:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo logs de auditoria',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/user/:id
 * Obtener resumen de auditoria de un usuario
 */
router.get('/user/:id', verificarToken, async (req, res) => {
  try {
    const { id } = req.params;

    const resumen = await AuditoriaService.obtenerResumenUsuario(parseInt(id));

    res.json({
      exito: true,
      resumen
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo resumen:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo resumen de usuario',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/suspicious/:id
 * Detectar actividad sospechosa de un usuario
 */
router.get('/suspicious/:id', verificarToken, async (req, res) => {
  try {
    const { id } = req.params;

    const analisis = await AuditoriaService.detectarActividadSospechosa(parseInt(id));

    res.json({
      exito: true,
      analisis
    });
  } catch (error) {
    console.error('[AUDIT API] Error detectando actividad:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error detectando actividad sospechosa',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/attempts
 * Obtener intentos de autenticacion
 */
router.get('/attempts', verificarToken, async (req, res) => {
  try {
    const {
      id_usuario,
      resultado,
      fecha_inicio,
      fecha_fin,
      es_sospechoso,
      limite = 100,
      offset = 0
    } = req.query;

    let query = 'SELECT * FROM intentos_autenticacion WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (id_usuario) {
      query += ` AND id_usuario = $${paramCount}`;
      params.push(id_usuario);
      paramCount++;
    }

    if (resultado) {
      query += ` AND resultado = $${paramCount}`;
      params.push(resultado);
      paramCount++;
    }

    if (fecha_inicio) {
      query += ` AND timestamp >= $${paramCount}`;
      params.push(fecha_inicio);
      paramCount++;
    }

    if (fecha_fin) {
      query += ` AND timestamp <= $${paramCount}`;
      params.push(fecha_fin);
      paramCount++;
    }

    if (es_sospechoso !== undefined) {
      query += ` AND es_sospechoso = $${paramCount}`;
      params.push(es_sospechoso === 'true');
      paramCount++;
    }

    query += ` ORDER BY timestamp DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
    params.push(limite, offset);

    const resultado_query = await pool.query(query, params);

    res.json({
      exito: true,
      intentos: resultado_query.rows,
      total: resultado_query.rowCount
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo intentos:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo intentos de autenticacion',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/security-events
 * Obtener eventos de seguridad
 */
router.get('/security-events', verificarToken, async (req, res) => {
  try {
    const {
      severidad,
      revisado,
      fecha_inicio,
      fecha_fin,
      limite = 100,
      offset = 0
    } = req.query;

    let query = 'SELECT * FROM eventos_seguridad WHERE 1=1';
    const params = [];
    let paramCount = 1;

    if (severidad) {
      query += ` AND severidad = $${paramCount}`;
      params.push(severidad);
      paramCount++;
    }

    if (revisado !== undefined) {
      query += ` AND revisado = $${paramCount}`;
      params.push(revisado === 'true');
      paramCount++;
    }

    if (fecha_inicio) {
      query += ` AND timestamp >= $${paramCount}`;
      params.push(fecha_inicio);
      paramCount++;
    }

    if (fecha_fin) {
      query += ` AND timestamp <= $${paramCount}`;
      params.push(fecha_fin);
      paramCount++;
    }

    query += ` ORDER BY timestamp DESC LIMIT $${paramCount} OFFSET $${paramCount + 1}`;
    params.push(limite, offset);

    const resultado_query = await pool.query(query, params);

    res.json({
      exito: true,
      eventos: resultado_query.rows,
      total: resultado_query.rowCount
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo eventos:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo eventos de seguridad',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/views/activity
 * Vista de actividad de usuarios
 */
router.get('/views/activity', verificarToken, async (req, res) => {
  try {
    const query = 'SELECT * FROM vista_actividad_usuarios ORDER BY total_acciones DESC';
    const resultado = await pool.query(query);

    res.json({
      exito: true,
      actividad: resultado.rows
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo vista de actividad:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo vista de actividad',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/views/failed-attempts
 * Vista de intentos fallidos
 */
router.get('/views/failed-attempts', verificarToken, async (req, res) => {
  try {
    const query = 'SELECT * FROM vista_intentos_fallidos ORDER BY intentos_fallidos DESC';
    const resultado = await pool.query(query);

    res.json({
      exito: true,
      intentos_fallidos: resultado.rows
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo intentos fallidos:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo vista de intentos fallidos',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/views/critical-events
 * Vista de eventos criticos
 */
router.get('/views/critical-events', verificarToken, async (req, res) => {
  try {
    const query = 'SELECT * FROM vista_eventos_criticos LIMIT 100';
    const resultado = await pool.query(query);

    res.json({
      exito: true,
      eventos_criticos: resultado.rows
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo eventos criticos:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo eventos criticos',
      error: error.message
    });
  }
});

/**
 * GET /api/audit/views/sensitive-changes
 * Vista de cambios en datos sensibles
 */
router.get('/views/sensitive-changes', verificarToken, async (req, res) => {
  try {
    const query = 'SELECT * FROM vista_cambios_sensibles LIMIT 100';
    const resultado = await pool.query(query);

    res.json({
      exito: true,
      cambios_sensibles: resultado.rows
    });
  } catch (error) {
    console.error('[AUDIT API] Error obteniendo cambios sensibles:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo cambios sensibles',
      error: error.message
    });
  }
});

/**
 * POST /api/audit/archive
 * Archivar logs antiguos
 */
router.post('/archive', verificarToken, async (req, res) => {
  try {
    const { dias_antiguedad = 365 } = req.body;

    const query = 'SELECT archivar_logs_antiguos($1)';
    const resultado = await pool.query(query, [dias_antiguedad]);

    res.json({
      exito: true,
      registros_archivados: resultado.rows[0].archivar_logs_antiguos,
      mensaje: `Se archivaron ${resultado.rows[0].archivar_logs_antiguos} registros`
    });
  } catch (error) {
    console.error('[AUDIT API] Error archivando logs:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error archivando logs antiguos',
      error: error.message
    });
  }
});

module.exports = router;
