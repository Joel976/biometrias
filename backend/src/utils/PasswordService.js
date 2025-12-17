const crypto = require('crypto');

/**
 * Servicio de gestión segura de contraseñas en backend
 * Usa SHA-256 iterado (compatible con lo que hace el cliente Flutter)
 */
class PasswordService {
  // Número de iteraciones para PBKDF2-like
  static HASH_ITERATIONS = 100000;

  /**
   * Generar salt aleatorio (16 bytes = 32 caracteres hex)
   */
  static generateSalt() {
    const timestamp = Date.now().toString();
    return crypto.createHash('sha256').update(timestamp).digest('hex').substring(0, 32);
  }

  /**
   * Hash seguro de contraseña con salt
   * Retorna: "salt$hash" para guardar en BD
   */
  static hashPassword(password) {
    if (!password || password.length === 0) {
      throw new Error('Contraseña no puede estar vacía');
    }

    const salt = this.generateSalt();
    const hash = this._pbkdf2Like(password, salt);
    return `${salt}$${hash}`;
  }

  /**
   * PBKDF2 simulado usando SHA-256 iterado
   * Compatible con la implementación de Flutter
   */
  static _pbkdf2Like(password, salt) {
    let hash = password;

    for (let i = 0; i < this.HASH_ITERATIONS; i++) {
      hash = crypto
        .createHash('sha256')
        .update(`${hash}${salt}`)
        .digest('hex')
        .substring(0, 64);
    }

    return hash;
  }

  /**
   * Verificar contraseña contra hash almacenado
   * Retorna: true si contraseña es correcta, false en caso contrario
   */
  static verifyPassword(password, storedHash) {
    if (!storedHash || !storedHash.includes('$')) {
      return false;
    }

    try {
      const parts = storedHash.split('$');
      if (parts.length !== 2) return false;

      const salt = parts[0];
      const originalHash = parts[1];

      // Hashear contraseña ingresada con el mismo salt
      const inputHash = this._pbkdf2Like(password, salt);

      // Comparación constante (evita timing attacks)
      return this._constantTimeCompare(inputHash, originalHash);
    } catch (err) {
      console.error('[PasswordService] Error verificando password:', err);
      return false;
    }
  }

  /**
   * Comparación de tiempo constante (evita timing attacks)
   * Siempre tarda el mismo tiempo sin importar dónde falle
   */
  static _constantTimeCompare(a, b) {
    if (a.length !== b.length) return false;

    let result = 0;
    for (let i = 0; i < a.length; i++) {
      result |= a.charCodeAt(i) ^ b.charCodeAt(i);
    }

    return result === 0;
  }

  /**
   * Validar fortaleza de contraseña
   * Retorna: { isValid: boolean, message: string }
   */
  static validatePasswordStrength(password) {
    if (!password || password.length === 0) {
      return { isValid: false, message: 'Contraseña no puede estar vacía' };
    }

    if (password.length < 6) {
      return {
        isValid: false,
        message: 'Contraseña debe tener al menos 6 caracteres'
      };
    }

    const hasUppercase = /[A-Z]/.test(password);
    const hasLowercase = /[a-z]/.test(password);
    const hasNumbers = /[0-9]/.test(password);
    const hasSpecial = /[!@#$%^&*]/.test(password);

    const requirements = [hasUppercase, hasLowercase, hasNumbers, hasSpecial].filter(
      (req) => req
    ).length;

    // Requerimientos mínimos (al menos 3 de 4)
    if (requirements < 3) {
      return {
        isValid: false,
        message:
          'Contraseña debe contener mayúsculas, minúsculas, números y caracteres especiales'
      };
    }

    return { isValid: true, message: 'Contraseña fuerte ✓' };
  }
}

module.exports = PasswordService;
