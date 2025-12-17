const express = require('express');
const router = express.Router();
const AuthController = require('../controllers/AuthController');
const { authenticateToken, refreshToken } = require('../middleware/auth');

// Rutas públicas
router.post('/register', AuthController.register);
router.post('/login', AuthController.loginBiometrico);
router.post('/login-basico', AuthController.loginBasico);
router.post('/refresh-token', refreshToken);

// Rutas de biometría (registro y verificación)
router.post('/biometria/registrar-oreja', AuthController.registerEarPhoto);
router.post('/biometria/registrar-voz', AuthController.registerVoiceAudio);
router.post('/biometria/verificar-oreja', AuthController.verificarOreja);
router.post('/biometria/verificar-voz', AuthController.verificarVoz);

// Rutas protegidas
router.post('/logout', authenticateToken, AuthController.logout);
router.get('/verify', authenticateToken, AuthController.verificarSesion);

module.exports = router;
