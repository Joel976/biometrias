const pool = require('../config/database');
const bcryptjs = require('bcryptjs');
const crypto = require('crypto');

class UsuarioModel {
  // Crear nuevo usuario
  static async crear(datos) {
    const {
      nombres,
      apellidos,
      fecha_nacimiento,
      sexo,
      identificador_unico,
      correo_electronico,
      numero_telefonico
    } = datos;

    const query = `
      INSERT INTO usuarios (
        nombres, apellidos, fecha_nacimiento, sexo, 
        identificador_unico, correo_electronico, numero_telefonico, estado
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'activo')
      RETURNING *
    `;

    try {
      const result = await pool.query(query, [
        nombres,
        apellidos,
        fecha_nacimiento,
        sexo,
        identificador_unico,
        correo_electronico,
        numero_telefonico
      ]);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al crear usuario: ${error.message}`);
    }
  }

  // Obtener usuario por ID
  static async obtenerPorId(id_usuario) {
    const query = `
      SELECT id_usuario, nombres, apellidos, fecha_nacimiento, sexo,
             identificador_unico, estado, fecha_registro, correo_electronico
      FROM usuarios
      WHERE id_usuario = $1
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      return result.rows[0] || null;
    } catch (error) {
      throw new Error(`Error al obtener usuario: ${error.message}`);
    }
  }

  // Obtener usuario por identificador único
  static async obtenerPorIdentificador(identificador_unico) {
    const query = `
      SELECT * FROM usuarios
      WHERE identificador_unico = $1
    `;

    try {
      const result = await pool.query(query, [identificador_unico]);
      return result.rows[0] || null;
    } catch (error) {
      throw new Error(`Error al obtener usuario: ${error.message}`);
    }
  }

  // Obtener todos los usuarios (paginado)
  static async obtenerTodos(pagina = 1, limite = 20) {
    const offset = (pagina - 1) * limite;
    const query = `
      SELECT id_usuario, nombres, apellidos, identificador_unico, 
             estado, fecha_registro, ultimo_acceso
      FROM usuarios
      ORDER BY fecha_registro DESC
      LIMIT $1 OFFSET $2
    `;

    try {
      const result = await pool.query(query, [limite, offset]);
      const countResult = await pool.query('SELECT COUNT(*) FROM usuarios');
      return {
        usuarios: result.rows,
        total: parseInt(countResult.rows[0].count),
        pagina,
        limite
      };
    } catch (error) {
      throw new Error(`Error al obtener usuarios: ${error.message}`);
    }
  }

  // Actualizar usuario
  static async actualizar(id_usuario, datos) {
    const campos = [];
    const valores = [];
    let contador = 1;

    for (const [clave, valor] of Object.entries(datos)) {
      if (valor !== undefined && valor !== null) {
        campos.push(`${clave} = $${contador}`);
        valores.push(valor);
        contador++;
      }
    }

    if (campos.length === 0) {
      return await this.obtenerPorId(id_usuario);
    }

    valores.push(id_usuario);
    const query = `
      UPDATE usuarios
      SET ${campos.join(', ')}
      WHERE id_usuario = $${contador}
      RETURNING *
    `;

    try {
      const result = await pool.query(query, valores);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al actualizar usuario: ${error.message}`);
    }
  }

  // Cambiar estado del usuario
  static async cambiarEstado(id_usuario, estado) {
    const query = `
      UPDATE usuarios
      SET estado = $1
      WHERE id_usuario = $2
      RETURNING *
    `;

    try {
      const result = await pool.query(query, [estado, id_usuario]);
      return result.rows[0];
    } catch (error) {
      throw new Error(`Error al cambiar estado: ${error.message}`);
    }
  }

  // Registrar último acceso
  static async registrarUltimoAcceso(id_usuario) {
    const query = `
      UPDATE usuarios
      SET ultimo_acceso = CURRENT_TIMESTAMP
      WHERE id_usuario = $1
    `;

    try {
      await pool.query(query, [id_usuario]);
    } catch (error) {
      console.error('Error al registrar último acceso:', error);
    }
  }

  // Eliminar usuario
  static async eliminar(id_usuario) {
    const query = `
      DELETE FROM usuarios
      WHERE id_usuario = $1
      RETURNING id_usuario
    `;

    try {
      const result = await pool.query(query, [id_usuario]);
      return result.rows.length > 0;
    } catch (error) {
      throw new Error(`Error al eliminar usuario: ${error.message}`);
    }
  }
}

module.exports = UsuarioModel;
