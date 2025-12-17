const express = require('express');
const router = express.Router();
const SincronizacionController = require('../controllers/SincronizacionController');
const { authenticateToken } = require('../middleware/auth');

// Ping sin autenticación
router.get('/ping', SincronizacionController.ping);

// Rutas protegidas
router.post('/descarga', authenticateToken, SincronizacionController.obtenerDatosDescarga);
// Aceptar subida sin autenticación para permitir registro offline
router.post('/subida', SincronizacionController.recibirDatosSubida);
router.get('/estado', authenticateToken, SincronizacionController.obtenerEstadoSync);
router.post('/reintento/:id_sync', authenticateToken, SincronizacionController.reintentarSync);
router.get('/cola-pendiente', authenticateToken, SincronizacionController.obtenerColaPendiente);
router.post('/confirmar', authenticateToken, SincronizacionController.confirmarSync);

module.exports = router;
