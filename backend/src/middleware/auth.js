const jwt = require('jsonwebtoken');
const pool = require('../config/database');

const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({ error: 'Token no proporcionado' });
    }

    jwt.verify(token, process.env.JWT_SECRET || 'secret_key', async (err, user) => {
      if (err) {
        // Token expirado, intentar refrescar
        if (err.name === 'TokenExpiredError') {
          return res.status(401).json({ error: 'Token expirado', code: 'TOKEN_EXPIRED' });
        }
        return res.status(403).json({ error: 'Token inválido' });
      }

      // Verificar que la sesión siga activa en la BD
      const result = await pool.query(
        'SELECT * FROM sesiones WHERE id_usuario = $1 AND token_acceso = $2 AND estado = $3',
        [user.id_usuario, token, 'activa']
      );

      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'Sesión inválida o expirada' });
      }

      req.user = user;
      next();
    });
  } catch (error) {
    console.error('Error en autenticación:', error);
    res.status(500).json({ error: 'Error en autenticación' });
  }
};

const refreshToken = async (req, res) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token requerido' });
    }

    jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET || 'refresh_secret', async (err, user) => {
      if (err) {
        return res.status(403).json({ error: 'Refresh token inválido' });
      }

      // Verificar en BD
      const result = await pool.query(
        'SELECT * FROM sesiones WHERE id_usuario = $1 AND refresh_token = $2',
        [user.id_usuario, refreshToken]
      );

      if (result.rows.length === 0) {
        return res.status(403).json({ error: 'Refresh token no encontrado' });
      }

      // Generar nuevo token de acceso
      const newAccessToken = jwt.sign(
        { id_usuario: user.id_usuario },
        process.env.JWT_SECRET || 'secret_key',
        { expiresIn: '1h' }
      );

      // Actualizar en BD
      await pool.query(
        'UPDATE sesiones SET token_acceso = $1, fecha_ultimo_uso = CURRENT_TIMESTAMP WHERE id_usuario = $2',
        [newAccessToken, user.id_usuario]
      );

      res.json({ 
        accessToken: newAccessToken,
        expiresIn: 3600
      });
    });
  } catch (error) {
    console.error('Error en refresh token:', error);
    res.status(500).json({ error: 'Error en refresh token' });
  }
};

module.exports = {
  authenticateToken,
  refreshToken
};
