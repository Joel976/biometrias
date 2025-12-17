const pool = require('../config/database');

class ValidacionBiometricaModel {
  // Registrar validación
  static async registrar(datos) {
    const {
      id_usuario,
      tipo_biometria,
      resultado,
      modo_validacion = 'online',
      ubicacion_gps,
      dispositivo_id,
      puntuacion_confianza,
      duracion_validacion,
      error_codigo
    } = datos;

    const query = `
      INSERT INTO validaciones_biometricas (
        id_usuario, tipo_biometria, resultado, modo_validacion,
        ubicacion_gps, dispositivo_id, puntuacion_confianza,
        duracion_validacion, error_codigo
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `;

    try {
      const result = await pool.query(query, [
        id_usuario,
        tipo_biometria,
        resultado,
        modo_validacion,
        ubicacion_gps,
        dispositivo_id,
        puntuacion_confianza,
        duracion_validacion,
        error_codigo
      ]);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al registrar validación: ${error.message}`);
    }
  }

  // Obtener validaciones del usuario
  static async obtenerPorUsuario(id_usuario, limite = 50, offset = 0) {
    const query = `
      SELECT * FROM validaciones_biometricas
      WHERE id_usuario = $1
      ORDER BY timestamp DESC
      LIMIT $2 OFFSET $3
    `;

    try {
      const result = await pool.query(query, [id_usuario, limite, offset]);
      const countResult = await pool.query(
        'SELECT COUNT(*) FROM validaciones_biometricas WHERE id_usuario = $1',
        [id_usuario]
      );
      return {
        validaciones: result.rows,
        total: parseInt(countResult.rows[0].count)
      };
    } catch (error) {
      throw new Error(`Error al obtener validaciones: ${error.message}`);
    }
  }

  // Obtener validaciones por dispositivo
  static async obtenerPorDispositivo(dispositivo_id, limite = 50) {
    const query = `
      SELECT * FROM validaciones_biometricas
      WHERE dispositivo_id = $1
      ORDER BY timestamp DESC
      LIMIT $2
    `;

    try {
      const result = await pool.query(query, [dispositivo_id, limite]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener validaciones por dispositivo: ${error.message}`);
    }
  }

  // Obtener estadísticas de validaciones
  static async obtenerEstadisticas(id_usuario, dias = 30) {
    const query = `
      SELECT 
        tipo_biometria,
        resultado,
        COUNT(*) as total,
        AVG(puntuacion_confianza) as confianza_promedio,
        AVG(duracion_validacion) as duracion_promedio
      FROM validaciones_biometricas
      WHERE id_usuario = $1
        AND timestamp > NOW() - INTERVAL '${dias} days'
      GROUP BY tipo_biometria, resultado
      ORDER BY tipo_biometria, resultado
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener estadísticas: ${error.message}`);
    }
  }

  // Obtener tasa de éxito
  static async obtenerTasaExito(id_usuario, tipo_biometria, dias = 30) {
    const query = `
      SELECT 
        resultado,
        COUNT(*) as cantidad
      FROM validaciones_biometricas
      WHERE id_usuario = $1 
        AND tipo_biometria = $2
        AND timestamp > NOW() - INTERVAL '${dias} days'
      GROUP BY resultado
    `;

    try {
      const result = await pool.query(query, [id_usuario, tipo_biometria]);
      let exitosas = 0, fallidas = 0;
      
      result.rows.forEach(row => {
        if (row.resultado === 'exito') exitosas = row.cantidad;
        if (row.resultado === 'fallo') fallidas = row.cantidad;
      });

      const total = exitosas + fallidas;
      const tasaExito = total > 0 ? (exitosas / total) * 100 : 0;

      return {
        exitosas,
        fallidas,
        total,
        tasaExito: parseFloat(tasaExito.toFixed(2))
      };
    } catch (error) {
      throw new Error(`Error al obtener tasa de éxito: ${error.message}`);
    }
  }

  // Obtener últimas N validaciones
  static async obtenerUltimas(id_usuario, cantidad = 10) {
    const query = `
      SELECT * FROM validaciones_biometricas
      WHERE id_usuario = $1
      ORDER BY timestamp DESC
      LIMIT $2
    `;

    try {
      const result = await pool.query(query, [id_usuario, cantidad]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener últimas validaciones: ${error.message}`);
    }
  }

  // Obtener validaciones fallidas recientes
  static async obtenerFallidasRecientes(id_usuario, horas = 24) {
    const query = `
      SELECT * FROM validaciones_biometricas
      WHERE id_usuario = $1 
        AND resultado = 'fallo'
        AND timestamp > NOW() - INTERVAL '${horas} hours'
      ORDER BY timestamp DESC
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener validaciones fallidas: ${error.message}`);
    }
  }
}

module.exports = ValidacionBiometricaModel;
