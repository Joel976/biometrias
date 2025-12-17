require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

const authRoutes = require('./routes/authRoutes');
const syncRoutes = require('./routes/syncRoutes');
const biometriaRoutes = require('./routes/biometriaRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de seguridad y logging
app.use(helmet());
app.use(compression());
app.use(morgan('dev'));
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  credentials: true
}));

// Parseo de JSON
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Rutas de salud
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Rutas API
app.use('/api/auth', authRoutes);
app.use('/api/sync', syncRoutes);
app.use('/api/biometria', biometriaRoutes);

// Manejo de errores 404
app.use((req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada',
    path: req.path,
    method: req.method
  });
});

// Manejo global de errores
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: err.message || 'Error interno del servidor',
    requestId: req.id
  });
});

// Iniciar servidor
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════════╗
║   Servidor Biométrico iniciado              ║
║   Puerto: ${PORT}                            
║   Entorno: ${process.env.NODE_ENV || 'desarrollo'}
║   Timestamp: ${new Date().toISOString()}
╚════════════════════════════════════════════╝
  `);
});

module.exports = app;
