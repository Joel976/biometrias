const pool = require('../config/database');
const crypto = require('crypto');

class CredencialBiometricaModel {
  // Crear nueva credencial biométrica
  static async crear(datos) {
    const {
      id_usuario,
      tipo_biometria,
      template,
      validez_desde,
      validez_hasta,
      version_algoritmo,
      calidad_captura
    } = datos;

    // Calcular hash de integridad
    const hash_integridad = crypto
      .createHash('sha256')
      .update(template)
      .digest('hex');

    const query = `
      INSERT INTO credenciales_biometricas (
        id_usuario, tipo_biometria, template, validez_desde, 
        validez_hasta, version_algoritmo, hash_integridad, 
        calidad_captura, estado
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'activo')
      RETURNING *
    `;

    try {
      const result = await pool.query(query, [
        id_usuario,
        tipo_biometria,
        template,
        validez_desde,
        validez_hasta,
        version_algoritmo,
        hash_integridad,
        calidad_captura
      ]);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al crear credencial biométrica: ${error.message}`);
    }
  }

  // Obtener credencial por ID
  static async obtenerPorId(id_credencial) {
    const query = `
      SELECT id_credencial, id_usuario, tipo_biometria, 
             fecha_captura, validez_hasta, version_algoritmo, 
             estado, calidad_captura, hash_integridad
      FROM credenciales_biometricas
      WHERE id_credencial = $1
    `;

    try {
      const result = await pool.query(query, [id_credencial]);
      return result.rows[0] || null;
    } catch (error) {
      throw new Error(`Error al obtener credencial: ${error.message}`);
    }
  }

  // Obtener template completo (incluye BYTEA)
  static async obtenerTemplateCompleto(id_credencial) {
    const query = `
      SELECT * FROM credenciales_biometricas
      WHERE id_credencial = $1
    `;

    try {
      const result = await pool.query(query, [id_credencial]);
      return result.rows[0] || null;
    } catch (error) {
      throw new Error(`Error al obtener template: ${error.message}`);
    }
  }

  // Obtener credenciales del usuario por tipo
  static async obtenerPorUsuarioYTipo(id_usuario, tipo_biometria) {
    const query = `
      SELECT id_credencial, id_usuario, tipo_biometria, 
             fecha_captura, validez_hasta, version_algoritmo, 
             estado, calidad_captura
      FROM credenciales_biometricas
      WHERE id_usuario = $1 
        AND tipo_biometria = $2
        AND estado = 'activo'
        AND (validez_hasta IS NULL OR validez_hasta > CURRENT_DATE)
      ORDER BY fecha_captura DESC
    `;

    try {
      const result = await pool.query(query, [id_usuario, tipo_biometria]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener credenciales: ${error.message}`);
    }
  }

  // Obtener todas las credenciales del usuario
  static async obtenerPorUsuario(id_usuario) {
    const query = `
      SELECT id_credencial, id_usuario, tipo_biometria, 
             fecha_captura, validez_hasta, version_algoritmo, 
             estado, calidad_captura
      FROM credenciales_biometricas
      WHERE id_usuario = $1
      ORDER BY tipo_biometria, fecha_captura DESC
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      return result.rows;
    } catch (error) {
      throw new Error(`Error al obtener credenciales: ${error.message}`);
    }
  }

  // Actualizar estado
  static async actualizarEstado(id_credencial, estado) {
    const query = `
      UPDATE credenciales_biometricas
      SET estado = $1
      WHERE id_credencial = $2
      RETURNING *
    `;

    try {
      const result = await pool.query(query, [estado, id_credencial]);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al actualizar estado: ${error.message}`);
    }
  }

  // Verificar integridad del template
  static async verificarIntegridad(id_credencial, template_data) {
    try {
      const credencial = await this.obtenerTemplateCompleto(id_credencial);
      if (!credencial) {
        return { valido: false, razon: 'Credencial no encontrada' };
      }

      const hash_calculado = crypto
        .createHash('sha256')
        .update(template_data)
        .digest('hex');

      const valido = hash_calculado === credencial.hash_integridad;
      return {
        valido,
        razon: valido ? 'OK' : 'Hash no coincide'
      };
    } catch (error) {
      throw new Error(`Error al verificar integridad: ${error.message}`);
    }
  }

  // Eliminar credencial (soft delete)
  static async eliminar(id_credencial) {
    return await this.actualizarEstado(id_credencial, 'eliminado');
  }

  // Contar credenciales vigentes por usuario
  static async contarVigentes(id_usuario) {
    const query = `
      SELECT tipo_biometria, COUNT(*) as cantidad
      FROM credenciales_biometricas
      WHERE id_usuario = $1 
        AND estado = 'activo'
        AND (validez_hasta IS NULL OR validez_hasta > CURRENT_DATE)
      GROUP BY tipo_biometria
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      const resumen = {};
      result.rows.forEach(row => {
        resumen[row.tipo_biometria] = row.cantidad;
      });
      return resumen;
    } catch (error) {
      throw new Error(`Error al contar credenciales: ${error.message}`);
    }
  }
}

module.exports = CredencialBiometricaModel;
