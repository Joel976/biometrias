/**
 * =====================================================
 * MIDDLEWARE DE AUDITORÍA COMPLETA
 * Sistema de Autenticación Biométrica
 * =====================================================
 */

const { pool } = require('../config/database');

/**
 * Servicio de Auditoría - Gestiona todos los logs del sistema
 */
class AuditoriaService {
  /**
   * Registrar acción en logs de auditoría
   * @param {Object} datos - Datos de la auditoría
   */
  static async registrarAccion(datos) {
    const {
      idUsuario = null,
      nombreUsuario = null,
      tipoAccion,
      entidadAfectada,
      idEntidadAfectada = null,
      descripcionAccion,
      valoresAntiguos = null,
      valoresNuevos = null,
      camposModificados = [],
      metodoHttp = null,
      endpoint = null,
      ipOrigen = null,
      userAgent = null,
      headersHttp = null,
      dispositivoId = null,
      tipoDispositivo = null,
      versionApp = null,
      sistemaOperativo = null,
      zonaHoraria = null,
      ubicacionGps = null,
      pais = null,
      ciudad = null,
      resultado = 'exito',
      codigoHttp = null,
      mensajeError = null,
      stackTrace = null,
      nivelRiesgo = 'bajo',
      requiereRevision = false,
      duracionMs = null,
      categoria = null,
      subcategoria = null,
      etiquetas = []
    } = datos;

    try {
      const query = `
        INSERT INTO logs_auditoria (
          id_usuario, nombre_usuario, tipo_accion, entidad_afectada, 
          id_entidad_afectada, descripcion_accion, valores_antiguos, 
          valores_nuevos, campos_modificados, metodo_http, endpoint, 
          ip_origen, user_agent, headers_http, dispositivo_id, 
          tipo_dispositivo, version_app, sistema_operativo, zona_horaria, 
          ubicacion_gps, pais, ciudad, resultado, codigo_http, 
          mensaje_error, stack_trace, nivel_riesgo, requiere_revision, 
          duracion_ms, categoria, subcategoria, etiquetas
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 
          $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, 
          $27, $28, $29, $30, $31, $32
        ) RETURNING id_log
      `;

      const valores = [
        idUsuario, nombreUsuario, tipoAccion, entidadAfectada,
        idEntidadAfectada, descripcionAccion,
        valoresAntiguos ? JSON.stringify(valoresAntiguos) : null,
        valoresNuevos ? JSON.stringify(valoresNuevos) : null,
        camposModificados, metodoHttp, endpoint, ipOrigen, userAgent,
        headersHttp ? JSON.stringify(headersHttp) : null,
        dispositivoId, tipoDispositivo, versionApp, sistemaOperativo,
        zonaHoraria, ubicacionGps, pais, ciudad, resultado, codigoHttp,
        mensajeError, stackTrace, nivelRiesgo, requiereRevision,
        duracionMs, categoria, subcategoria, etiquetas
      ];

      const resultado_query = await pool.query(query, valores);
      
      console.log(`[AUDITORÍA] Acción registrada: ${tipoAccion} en ${entidadAfectada} (ID: ${resultado_query.rows[0].id_log})`);
      
      return resultado_query.rows[0].id_log;
    } catch (error) {
      console.error('[AUDITORÍA] Error registrando acción:', error);
      // No lanzar error para evitar interrumpir la operación principal
      return null;
    }
  }

  /**
   * Registrar intento de autenticación
   */
  static async registrarIntentoAuth(datos) {
    const {
      idUsuario = null,
      identificadorIngresado,
      tipoAutenticacion,
      resultado,
      puntuacionConfianza = null,
      umbralRequerido = null,
      tipoBiometria = null,
      ipOrigen = null,
      dispositivoId = null,
      userAgent = null,
      ubicacionGps = null,
      intentosConsecutivos = 1,
      esSospechoso = false,
      razonSospecha = null,
      duracionMs = null
    } = datos;

    try {
      const query = `
        INSERT INTO intentos_autenticacion (
          id_usuario, identificador_ingresado, tipo_autenticacion, 
          resultado, puntuacion_confianza, umbral_requerido, 
          tipo_biometria, ip_origen, dispositivo_id, user_agent, 
          ubicacion_gps, intentos_consecutivos, es_sospechoso, 
          razon_sospecha, duracion_ms
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING id_intento
      `;

      const valores = [
        idUsuario, identificadorIngresado, tipoAutenticacion, resultado,
        puntuacionConfianza, umbralRequerido, tipoBiometria, ipOrigen,
        dispositivoId, userAgent, ubicacionGps, intentosConsecutivos,
        esSospechoso, razonSospecha, duracionMs
      ];

      const resultado_query = await pool.query(query, valores);
      
      console.log(`[AUTH] Intento registrado: ${resultado} para ${identificadorIngresado}`);
      
      // Si es sospechoso, crear evento de seguridad
      if (esSospechoso) {
        await this.registrarEventoSeguridad({
          tipoEvento: 'intento_autenticacion_sospechoso',
          severidad: 'warning',
          idUsuario,
          descripcion: `Intento sospechoso de autenticación: ${razonSospecha}`,
          detallesJson: { identificador: identificadorIngresado, tipo: tipoAutenticacion },
          ipOrigen,
          dispositivoId,
          requiereRevision: true
        });
      }
      
      return resultado_query.rows[0].id_intento;
    } catch (error) {
      console.error('[AUTH] Error registrando intento:', error);
      return null;
    }
  }

  /**
   * Registrar cambio en datos sensibles
   */
  static async registrarCambioSensible(datos) {
    const {
      idUsuario,
      nombreCompleto,
      tipoDato,
      campoModificado,
      valorAnterior = null,
      valorNuevo = null,
      hashValorAnterior = null,
      hashValorNuevo = null,
      idUsuarioEjecutor = null,
      nombreEjecutor = null,
      tipoEjecutor = 'usuario',
      ipOrigen = null,
      motivoCambio = null,
      requiereAprobacion = false
    } = datos;

    try {
      const query = `
        INSERT INTO auditoria_datos_sensibles (
          id_usuario, nombre_completo, tipo_dato, campo_modificado,
          valor_anterior, valor_nuevo, hash_valor_anterior, 
          hash_valor_nuevo, id_usuario_ejecutor, nombre_ejecutor,
          tipo_ejecutor, ip_origen, motivo_cambio, requiere_aprobacion
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        RETURNING id_auditoria
      `;

      const valores = [
        idUsuario, nombreCompleto, tipoDato, campoModificado,
        valorAnterior, valorNuevo, hashValorAnterior, hashValorNuevo,
        idUsuarioEjecutor, nombreEjecutor, tipoEjecutor, ipOrigen,
        motivoCambio, requiereAprobacion
      ];

      const resultado = await pool.query(query, valores);
      
      console.log(`[DATOS SENSIBLES] Cambio registrado en ${tipoDato}.${campoModificado}`);
      
      return resultado.rows[0].id_auditoria;
    } catch (error) {
      console.error('[DATOS SENSIBLES] Error:', error);
      return null;
    }
  }

  /**
   * Registrar evento de seguridad
   */
  static async registrarEventoSeguridad(datos) {
    const {
      tipoEvento,
      severidad,
      idUsuario = null,
      descripcion,
      detallesJson = null,
      ipOrigen = null,
      dispositivoId = null,
      ubicacion = null,
      accionAutomatica = 'ninguna',
      requiereRevision = false
    } = datos;

    try {
      const query = `
        INSERT INTO eventos_seguridad (
          tipo_evento, severidad, id_usuario, descripcion, 
          detalles_json, ip_origen, dispositivo_id, ubicacion,
          accion_automatica, requiere_revision
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING id_evento
      `;

      const valores = [
        tipoEvento, severidad, idUsuario, descripcion,
        detallesJson ? JSON.stringify(detallesJson) : null,
        ipOrigen, dispositivoId, ubicacion, accionAutomatica,
        requiereRevision
      ];

      const resultado = await pool.query(query, valores);
      
      console.log(`[SEGURIDAD] Evento ${severidad}: ${tipoEvento}`);
      
      // Si es crítico, podríamos enviar alerta
      if (severidad === 'critical') {
        console.error(`🚨 EVENTO CRÍTICO DE SEGURIDAD: ${descripcion}`);
        // Aquí podrías enviar email, SMS, etc.
      }
      
      return resultado.rows[0].id_evento;
    } catch (error) {
      console.error('[SEGURIDAD] Error registrando evento:', error);
      return null;
    }
  }

  /**
   * Registrar acción administrativa
   */
  static async registrarAccionAdmin(datos) {
    const {
      idAdmin,
      nombreAdmin,
      rolAdmin,
      accion,
      entidadAfectada,
      idEntidad = null,
      descripcion,
      parametrosJson = null,
      valoresAnteriores = null,
      valoresNuevos = null,
      ipOrigen = null,
      motivo = null,
      ticketSoporte = null,
      resultado = 'exito',
      mensajeError = null
    } = datos;

    try {
      const query = `
        INSERT INTO auditoria_admin (
          id_admin, nombre_admin, rol_admin, accion, entidad_afectada,
          id_entidad, descripcion, parametros_json, valores_anteriores,
          valores_nuevos, ip_origen, motivo, ticket_soporte, resultado,
          mensaje_error
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        RETURNING id_auditoria
      `;

      const valores = [
        idAdmin, nombreAdmin, rolAdmin, accion, entidadAfectada,
        idEntidad, descripcion,
        parametrosJson ? JSON.stringify(parametrosJson) : null,
        valoresAnteriores ? JSON.stringify(valoresAnteriores) : null,
        valoresNuevos ? JSON.stringify(valoresNuevos) : null,
        ipOrigen, motivo, ticketSoporte, resultado, mensajeError
      ];

      const resultado_query = await pool.query(query, valores);
      
      console.log(`[ADMIN] Acción: ${accion} en ${entidadAfectada} por ${nombreAdmin}`);
      
      return resultado_query.rows[0].id_auditoria;
    } catch (error) {
      console.error('[ADMIN] Error registrando acción:', error);
      return null;
    }
  }

  /**
   * Detectar actividad sospechosa de un usuario
   */
  static async detectarActividadSospechosa(idUsuario) {
    try {
      const query = `SELECT * FROM detectar_actividad_sospechosa($1)`;
      const resultado = await pool.query(query, [idUsuario]);
      
      return resultado.rows[0];
    } catch (error) {
      console.error('[SEGURIDAD] Error detectando actividad sospechosa:', error);
      return { es_sospechoso: false, razones: [] };
    }
  }

  /**
   * Obtener resumen de auditoría de un usuario
   */
  static async obtenerResumenUsuario(idUsuario) {
    try {
      const query = `SELECT * FROM obtener_resumen_auditoria_usuario($1)`;
      const resultado = await pool.query(query, [idUsuario]);
      
      return resultado.rows[0];
    } catch (error) {
      console.error('[AUDITORÍA] Error obteniendo resumen:', error);
      return null;
    }
  }
}

/**
 * Middleware de Express para auditoría automática
 */
function middlewareAuditoria(req, res, next) {
  // Capturar tiempo de inicio
  const tiempoInicio = Date.now();
  
  // Extraer información del request
  const datosBase = {
    metodoHttp: req.method,
    endpoint: req.originalUrl || req.url,
    ipOrigen: req.ip || req.connection.remoteAddress,
    userAgent: req.get('user-agent'),
    headersHttp: {
      'content-type': req.get('content-type'),
      'accept': req.get('accept')
    }
  };

  // Interceptar el response para capturar el código de estado
  const originalSend = res.send;
  res.send = function(data) {
    res.send = originalSend;
    
    // Calcular duración
    const duracionMs = Date.now() - tiempoInicio;
    
    // Registrar acción si es relevante
    const metodosRelevantes = ['POST', 'PUT', 'DELETE', 'PATCH'];
    if (metodosRelevantes.includes(req.method)) {
      const datosAuditoria = {
        ...datosBase,
        idUsuario: req.usuario?.id_usuario || null,
        nombreUsuario: req.usuario ? `${req.usuario.nombres} ${req.usuario.apellidos}` : null,
        tipoAccion: req.method,
        entidadAfectada: req.baseUrl || 'desconocido',
        descripcionAccion: `${req.method} ${req.originalUrl}`,
        valoresNuevos: req.body,
        codigoHttp: res.statusCode,
        resultado: res.statusCode < 400 ? 'exito' : 'error',
        duracionMs,
        categoria: 'api'
      };
      
      // Registrar de forma asíncrona para no bloquear el response
      AuditoriaService.registrarAccion(datosAuditoria).catch(err => 
        console.error('[MIDDLEWARE] Error en auditoría:', err)
      );
    }
    
    return originalSend.call(this, data);
  };
  
  next();
}

/**
 * Middleware para auditar intentos de login
 */
function middlewareAuditoriaLogin(req, res, next) {
  const tiempoInicio = Date.now();
  
  // Interceptar response
  const originalJson = res.json;
  res.json = function(data) {
    res.json = originalJson;
    
    const duracionMs = Date.now() - tiempoInicio;
    const exitoso = res.statusCode === 200 || res.statusCode === 201;
    
    // Registrar intento de autenticación
    AuditoriaService.registrarIntentoAuth({
      identificadorIngresado: req.body.identificador_unico || req.body.identificadorUnico,
      tipoAutenticacion: req.body.tipo_biometria ? `biometrica_${req.body.tipo_biometria}` : 'password',
      resultado: exitoso ? 'exito' : 'fallo_credencial',
      ipOrigen: req.ip || req.connection.remoteAddress,
      dispositivoId: req.body.dispositivo_id || req.get('device-id'),
      userAgent: req.get('user-agent'),
      duracionMs
    }).catch(err => console.error('[LOGIN] Error en auditoría:', err));
    
    return originalJson.call(this, data);
  };
  
  next();
}

module.exports = {
  AuditoriaService,
  middlewareAuditoria,
  middlewareAuditoriaLogin
};
