const express = require('express');
const router = express.Router();
const AuthController = require('../controllers/AuthController');

// Rutas públicas para biometría
router.post('/registrar-oreja', AuthController.registerEarPhoto);
router.post('/registrar-voz', AuthController.registerVoiceAudio);
router.post('/verificar-oreja', AuthController.verificarOreja);
router.post('/verificar-voz', AuthController.verificarVoz);

module.exports = router;
