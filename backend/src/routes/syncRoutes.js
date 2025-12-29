const express = require('express');
const router = express.Router();
const SincronizacionController = require('../controllers/SincronizacionController');
const { authenticateToken } = require('../middleware/auth');
const SyncFlagsService = require('../services/SyncFlagsService');

// Ping sin autenticación
router.get('/ping', SincronizacionController.ping);

// Rutas protegidas
router.post('/descarga', authenticateToken, SincronizacionController.obtenerDatosDescarga);
// Aceptar subida sin autenticación para permitir registro offline
router.post('/subida', SincronizacionController.recibirDatosSubida);
router.get('/estado', authenticateToken, SincronizacionController.obtenerEstadoSync);
router.post('/reintento/:id_sync', authenticateToken, SincronizacionController.reintentarSync);
router.get('/cola-pendiente', authenticateToken, SincronizacionController.obtenerColaPendiente);
router.post('/confirmar', SincronizacionController.confirmarSync);

// ============================================
// NUEVAS RUTAS DE BANDERAS DE SINCRONIZACION
// ============================================

/**
 * GET /api/sync/flags/pending
 * Obtener elementos pendientes de sincronizacion
 */
router.get('/flags/pending', authenticateToken, async (req, res) => {
  try {
    const { id_usuario } = req.usuario;
    const { dispositivo_id, entidad } = req.query;

    if (!dispositivo_id) {
      return res.status(400).json({
        exito: false,
        mensaje: 'dispositivo_id es requerido'
      });
    }

    const pendientes = await SyncFlagsService.obtenerPendientesSincronizacion(
      id_usuario,
      dispositivo_id,
      entidad || null
    );

    res.json({
      exito: true,
      pendientes,
      total: pendientes.length
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error obteniendo pendientes:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo pendientes de sincronizacion',
      error: error.message
    });
  }
});

/**
 * POST /api/sync/flags/mark-synced
 * Marcar elemento(s) como sincronizado(s)
 */
router.post('/flags/mark-synced', authenticateToken, async (req, res) => {
  try {
    const { entidad, id_entidad, dispositivo_id, lote } = req.body;

    if (!dispositivo_id) {
      return res.status(400).json({
        exito: false,
        mensaje: 'dispositivo_id es requerido'
      });
    }

    // Marcar lote de elementos
    if (lote && Array.isArray(lote)) {
      const resultados = await SyncFlagsService.marcarLoteComoSincronizado(lote, dispositivo_id);
      
      return res.json({
        exito: true,
        mensaje: `${resultados.exitosos} elementos sincronizados`,
        resultados
      });
    }

    // Marcar elemento individual
    if (!entidad || !id_entidad) {
      return res.status(400).json({
        exito: false,
        mensaje: 'entidad e id_entidad son requeridos'
      });
    }

    const exitoso = await SyncFlagsService.marcarComoSincronizado(
      entidad,
      id_entidad,
      dispositivo_id
    );

    res.json({
      exito: exitoso,
      mensaje: exitoso ? 'Elemento marcado como sincronizado' : 'No se pudo marcar el elemento'
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error marcando como sincronizado:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error marcando elementos como sincronizados',
      error: error.message
    });
  }
});

/**
 * GET /api/sync/flags/status
 * Obtener estado de sincronizacion del usuario
 */
router.get('/flags/status', authenticateToken, async (req, res) => {
  try {
    const { id_usuario } = req.usuario;

    const estado = await SyncFlagsService.obtenerEstadoSincronizacion(id_usuario);

    if (!estado) {
      return res.status(404).json({
        exito: false,
        mensaje: 'No se encontro estado de sincronizacion'
      });
    }

    res.json({
      exito: true,
      estado
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error obteniendo estado:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo estado de sincronizacion',
      error: error.message
    });
  }
});

/**
 * POST /api/sync/flags/checkpoint
 * Crear checkpoint de sincronizacion
 */
router.post('/flags/checkpoint', authenticateToken, async (req, res) => {
  try {
    const { id_usuario } = req.usuario;
    const { dispositivo_id, nombre_checkpoint, notas } = req.body;

    if (!dispositivo_id) {
      return res.status(400).json({
        exito: false,
        mensaje: 'dispositivo_id es requerido'
      });
    }

    const idCheckpoint = await SyncFlagsService.crearCheckpoint(
      id_usuario,
      dispositivo_id,
      nombre_checkpoint,
      notas
    );

    if (!idCheckpoint) {
      return res.status(500).json({
        exito: false,
        mensaje: 'No se pudo crear el checkpoint'
      });
    }

    res.json({
      exito: true,
      mensaje: 'Checkpoint creado exitosamente',
      id_checkpoint: idCheckpoint
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error creando checkpoint:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error creando checkpoint',
      error: error.message
    });
  }
});

/**
 * GET /api/sync/flags/checkpoints
 * Obtener checkpoints del usuario
 */
router.get('/flags/checkpoints', authenticateToken, async (req, res) => {
  try {
    const { id_usuario } = req.usuario;
    const { dispositivo_id, limite = 10 } = req.query;

    if (!dispositivo_id) {
      return res.status(400).json({
        exito: false,
        mensaje: 'dispositivo_id es requerido'
      });
    }

    const checkpoints = await SyncFlagsService.obtenerCheckpoints(
      id_usuario,
      dispositivo_id,
      parseInt(limite)
    );

    res.json({
      exito: true,
      checkpoints,
      total: checkpoints.length
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error obteniendo checkpoints:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo checkpoints',
      error: error.message
    });
  }
});

/**
 * GET /api/sync/flags/conflicts
 * Obtener conflictos de sincronizacion
 */
router.get('/flags/conflicts', authenticateToken, async (req, res) => {
  try {
    const { id_usuario } = req.usuario;
    const { dispositivo_id } = req.query;

    const conflictos = await SyncFlagsService.obtenerConflictos(id_usuario, dispositivo_id);

    res.json({
      exito: true,
      conflictos,
      total: conflictos.length
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error obteniendo conflictos:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo conflictos',
      error: error.message
    });
  }
});

/**
 * POST /api/sync/flags/resolve-conflict
 * Resolver conflicto de sincronizacion
 */
router.post('/flags/resolve-conflict', authenticateToken, async (req, res) => {
  try {
    const { id_metadata, resolucion } = req.body;

    if (!id_metadata || !resolucion) {
      return res.status(400).json({
        exito: false,
        mensaje: 'id_metadata y resolucion son requeridos'
      });
    }

    const resultado = await SyncFlagsService.resolverConflicto(id_metadata, resolucion);

    if (!resultado) {
      return res.status(404).json({
        exito: false,
        mensaje: 'No se pudo resolver el conflicto'
      });
    }

    res.json({
      exito: true,
      mensaje: 'Conflicto resuelto exitosamente',
      conflicto: resultado
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error resolviendo conflicto:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error resolviendo conflicto',
      error: error.message
    });
  }
});

/**
 * GET /api/sync/flags/all-status
 * Obtener estado de sincronizacion de todos los usuarios (admin)
 */
router.get('/flags/all-status', authenticateToken, async (req, res) => {
  try {
    const estados = await SyncFlagsService.obtenerTodosLosEstados();

    res.json({
      exito: true,
      estados,
      total: estados.length
    });
  } catch (error) {
    console.error('[SYNC FLAGS] Error obteniendo estados:', error);
    res.status(500).json({
      exito: false,
      mensaje: 'Error obteniendo estados de sincronizacion',
      error: error.message
    });
  }
});

module.exports = router;
