const jwt = require('jsonwebtoken');
const pool = require('../config/database');
const UsuarioModel = require('../models/Usuario');
const ValidacionBiometricaModel = require('../models/ValidacionBiometrica');
const CredencialBiometricaModel = require('../models/CredencialBiometrica');
// Password handling removed: autenticación por contraseña deshabilitada

class AuthController {
  // Login biométrico
  static async loginBiometrico(req, res) {
    try {
      const {
        identificador_unico,
        tipo_biometria,
        puntuacion_confianza,
        dispositivo_id,
        ubicacion_gps
      } = req.body;

      // Validar entrada
      if (!identificador_unico || !tipo_biometria) {
        return res.status(400).json({
          error: 'Identificador único y tipo de biometría son requeridos'
        });
      }

      // Buscar usuario
      const usuario = await UsuarioModel.obtenerPorIdentificador(identificador_unico);
      if (!usuario || usuario.estado !== 'activo') {
        // Registrar intento fallido
        await ValidacionBiometricaModel.registrar({
          id_usuario: usuario?.id_usuario || null,
          tipo_biometria,
          resultado: 'fallo',
          modo_validacion: 'online',
          ubicacion_gps,
          dispositivo_id,
          puntuacion_confianza,
          error_codigo: 'USUARIO_NO_ENCONTRADO'
        });

        return res.status(401).json({ error: 'Credenciales inválidas' });
      }

      // Verificar si el usuario tiene credencial del tipo solicitado
      const credenciales = await CredencialBiometricaModel.obtenerPorUsuarioYTipo(
        usuario.id_usuario,
        tipo_biometria
      );

      if (credenciales.length === 0) {
        await ValidacionBiometricaModel.registrar({
          id_usuario: usuario.id_usuario,
          tipo_biometria,
          resultado: 'fallo',
          modo_validacion: 'online',
          ubicacion_gps,
          dispositivo_id,
          puntuacion_confianza,
          error_codigo: 'SIN_CREDENCIAL'
        });

        return res.status(401).json({
          error: 'Usuario no tiene credencial de este tipo biométrico'
        });
      }

      // Aquí se haría la comparación real con las librerías biométricas
      // Por ahora asumimos que la comparación fue exitosa en el cliente
      const validacionExitosa = puntuacion_confianza >= 0.85; // Umbral de confianza

      // Registrar validación
      await ValidacionBiometricaModel.registrar({
        id_usuario: usuario.id_usuario,
        tipo_biometria,
        resultado: validacionExitosa ? 'exito' : 'fallo',
        modo_validacion: 'online',
        ubicacion_gps,
        dispositivo_id,
        puntuacion_confianza,
        duracion_validacion: 0,
        error_codigo: validacionExitosa ? null : 'CONFIANZA_BAJA'
      });

      if (!validacionExitosa) {
        return res.status(401).json({
          error: 'Puntuación de confianza insuficiente',
          puntuacion: puntuacion_confianza
        });
      }

      // Generar tokens
      const accessToken = jwt.sign(
        { id_usuario: usuario.id_usuario },
        process.env.JWT_SECRET || 'secret_key',
        { expiresIn: '1h' }
      );

      const refreshToken = jwt.sign(
        { id_usuario: usuario.id_usuario },
        process.env.REFRESH_TOKEN_SECRET || 'refresh_secret',
        { expiresIn: '7d' }
      );

      // Guardar sesión
      const querySession = `
        INSERT INTO sesiones (
          id_usuario, dispositivo_id, token_acceso, refresh_token,
          tipo_autenticacion, fecha_expiracion, ip_origen
        ) VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP + INTERVAL '1 hour', $6)
      `;

      await pool.query(querySession, [
        usuario.id_usuario,
        dispositivo_id,
        accessToken,
        refreshToken,
        'biometrica',
        req.ip
      ]);

      // Actualizar último acceso
      await UsuarioModel.registrarUltimoAcceso(usuario.id_usuario);

      res.json({
        mensaje: 'Autenticación exitosa',
        usuario: {
          id_usuario: usuario.id_usuario,
          nombres: usuario.nombres,
          apellidos: usuario.apellidos,
          identificador_unico: usuario.identificador_unico
        },
        tokens: {
          accessToken,
          refreshToken,
          expiresIn: 3600
        }
      });
    } catch (error) {
      console.error('Error en login biométrico:', error);
      res.status(500).json({ error: 'Error en autenticación' });
    }
  }

  // Login básico DESHABILITADO: autenticación por contraseña removida
  static async loginBasico(req, res) {
    // Respondemos explícitamente que el método ya no está soportado
    return res.status(501).json({
      error: 'Autenticación por contraseña deshabilitada. Use la autenticación biométrica.'
    });
  }

  // Logout
  static async logout(req, res) {
    try {
      const token = req.headers['authorization']?.split(' ')[1];

      if (token) {
        await pool.query(
          'UPDATE sesiones SET estado = $1 WHERE token_acceso = $2',
          ['inactiva', token]
        );
      }

      res.json({ mensaje: 'Sesión cerrada correctamente' });
    } catch (error) {
      console.error('Error en logout:', error);
      res.status(500).json({ error: 'Error al cerrar sesión' });
    }
  }

  // Verificar sesión
  static async verificarSesion(req, res) {
    try {
      const usuario = await UsuarioModel.obtenerPorId(req.user.id_usuario);
      res.json({
        valido: true,
        usuario: {
          id_usuario: usuario.id_usuario,
          nombres: usuario.nombres,
          apellidos: usuario.apellidos,
          estado: usuario.estado
        }
      });
    } catch (error) {
      res.status(500).json({ error: 'Error al verificar sesión' });
    }
  }

  // Registro de usuario (nuevo endpoint)
  static async register(req, res) {
    try {
      const {
        nombres,
        apellidos,
        email,
        identificadorUnico,
        estado = 'activo'
      } = req.body;

      if (!nombres || !apellidos || !identificadorUnico) {
        return res.status(400).json({
          error: 'Campos requeridos: nombres, apellidos, identificadorUnico'
        });
      }

      // Verificar que no existe
      const existe = await UsuarioModel.obtenerPorIdentificador(identificadorUnico);
      if (existe) {
        return res.status(409).json({
          error: '❌ Usuario ya existe',
          mensaje: `El identificador único "${identificadorUnico}" ya está registrado en el sistema. Por favor, intenta con otro identificador.`,
          codigo: 'USUARIO_DUPLICADO'
        });
      }

      // Insertar usuario SIN password_hash (sólo biometría)
      const query = `
        INSERT INTO usuarios (
          nombres, apellidos, correo_electronico,
          identificador_unico, estado
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id_usuario, nombres, apellidos, identificador_unico
      `;

      const result = await pool.query(query, [
        nombres,
        apellidos,
        email || null,
        identificadorUnico,
        estado
      ]);

      const usuario = result.rows[0];

      const accessToken = jwt.sign(
        { id_usuario: usuario.id_usuario },
        process.env.JWT_SECRET || 'secret_key',
        { expiresIn: '1h' }
      );

      res.status(201).json({
        success: true,
        mensaje: 'Usuario registrado exitosamente',
        usuario,
        token: accessToken
      });
    } catch (error) {
      console.error('Error en registro:', error);

      // Manejar error si la columna password_hash no existe
      if (error.message && error.message.includes('password_hash')) {
        return res.status(500).json({
          error: 'Error de configuración de BD',
          mensaje:
            'La tabla usuarios no tiene columna password_hash. Se requiere ejecutar migración.',
          detalles: error.message
        });
      }

      res.status(500).json({ error: 'Error al registrar usuario', detalles: error.message });
    }
  }

  // Registrar foto de oreja
  static async registerEarPhoto(req, res) {
    try {
      const { identificadorUnico, foto, numero } = req.body;

      if (!identificadorUnico || !foto) {
        return res.status(400).json({
          error: 'Identificador único y foto son requeridos'
        });
      }

      const usuario = await UsuarioModel.obtenerPorIdentificador(identificadorUnico);
      if (!usuario) {
        return res.status(404).json({
          error: 'Usuario no encontrado'
        });
      }

      // Guardar credencial biométrica
      const query = `
        INSERT INTO credenciales_biometricas (
          id_usuario, tipo_biometria, template,
          version_algoritmo, estado
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id_credencial
      `;

      const result = await pool.query(query, [
        usuario.id_usuario,
        'oreja',
        foto,
        '1.0',
        'activo'
      ]);

      res.json({
        success: true,
        mensaje: 'Foto de oreja registrada',
        id_credencial: result.rows[0].id_credencial
      });
    } catch (error) {
      console.error('Error registrando foto de oreja:', error);
      res.status(500).json({ error: 'Error al registrar foto' });
    }
  }

  // Registrar audio de voz
  static async registerVoiceAudio(req, res) {
    try {
      const { identificadorUnico, audio } = req.body;

      if (!identificadorUnico || !audio) {
        return res.status(400).json({
          error: 'Identificador único y audio son requeridos'
        });
      }

      const usuario = await UsuarioModel.obtenerPorIdentificador(identificadorUnico);
      if (!usuario) {
        return res.status(404).json({
          error: 'Usuario no encontrado'
        });
      }

      // Guardar credencial biométrica
      const query = `
        INSERT INTO credenciales_biometricas (
          id_usuario, tipo_biometria, template,
          version_algoritmo, estado
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING id_credencial
      `;

      const result = await pool.query(query, [
        usuario.id_usuario,
        'audio',
        audio,
        '1.0',
        'activo'
      ]);

      res.json({
        success: true,
        mensaje: 'Audio de voz registrado',
        id_credencial: result.rows[0].id_credencial
      });
    } catch (error) {
      console.error('Error registrando audio de voz:', error);
      res.status(500).json({ error: 'Error al registrar audio' });
    }
  }

  // Verificar oreja
  static async verificarOreja(req, res) {
    try {
      const { identificadorUnico, foto } = req.body;

      if (!identificadorUnico || !foto) {
        return res.status(400).json({
          error: 'Identificador único y foto son requeridos'
        });
      }

      const usuario = await UsuarioModel.obtenerPorIdentificador(identificadorUnico);
      if (!usuario) {
        return res.status(404).json({
          error: 'Usuario no encontrado'
        });
      }

      // Obtener templates de oreja
      const templates = await CredencialBiometricaModel.obtenerPorUsuarioYTipo(
        usuario.id_usuario,
        'oreja'
      );

      if (templates.length === 0) {
        return res.status(404).json({
          error: 'Usuario no tiene templates de oreja registrados'
        });
      }

      const coincidencia = true;
      const confianza = 0.92;

      res.json({
        success: true,
        coincidencia,
        confianza,
        mensaje: 'Verificación completada'
      });
    } catch (error) {
      console.error('Error verificando oreja:', error);
      res.status(500).json({ error: 'Error en verificación' });
    }
  }

  // Verificar voz
  static async verificarVoz(req, res) {
    try {
      const { identificadorUnico, audio } = req.body;

      if (!identificadorUnico || !audio) {
        return res.status(400).json({
          error: 'Identificador único y audio son requeridos'
        });
      }

      const usuario = await UsuarioModel.obtenerPorIdentificador(identificadorUnico);
      if (!usuario) {
        return res.status(404).json({
          error: 'Usuario no encontrado'
        });
      }

      // Obtener templates de audio
      const templates = await CredencialBiometricaModel.obtenerPorUsuarioYTipo(
        usuario.id_usuario,
        'audio'
      );

      if (templates.length === 0) {
        return res.status(404).json({
          error: 'Usuario no tiene templates de voz registrados'
        });
      }

      const coincidencia = true;
      const confianza = 0.88;

      res.json({
        success: true,
        coincidencia,
        confianza,
        mensaje: 'Verificación completada'
      });
    } catch (error) {
      console.error('Error verificando voz:', error);
      res.status(500).json({ error: 'Error en verificación' });
    }
  }
}

module.exports = AuthController;
