#ifndef OREJA_MOBILE_API_H
#define OREJA_MOBILE_API_H

#include <stdint.h>
#include <stddef.h>

// ============================================================================
// API C para FFI (Flutter/Dart) - Biometría de OREJA (Mobile)
// ============================================================================

#ifdef __cplusplus
extern "C"
{
#endif

    // ============================================================================
    // GESTION DE LIBRERIA
    // ============================================================================

    /**
     * Inicializar la libreria biometrica de oreja
     * @param model_dir Directorio con modelos (zscore_params.dat, modelo_pca.dat, modelo_lda.dat)
     * @param dataset_csv Ruta CSV con dataset LDA (ej: out/caracteristicas_lda_train.csv)
     * @param templates_csv Ruta CSV de templates (ej: out/templates_k1.csv)
     * @return 0 si exito, -1 si error
     */
    int oreja_mobile_init(const char *model_dir,
                          const char *dataset_csv,
                          const char *templates_csv);

    /**
     * Liberar recursos de la libreria
     */
    void oreja_mobile_cleanup();

    /**
     * Obtener version de la libreria
     * @return String con la version (ej: "1.0.0")
     */
    const char *oreja_mobile_version();

    /**
     * Recargar templates desde disco (templates_k1.csv)
     * @return 0 si exito, -1 si error
     */
    int oreja_mobile_reload_templates();

    // ============================================================================
    // REGISTRO BIOMETRICO
    // ============================================================================

    /**
     * Registrar biometria de oreja (agrega vectores y actualiza templates)
     * @param identificador_unico ID del usuario (entero)
     * @param image_paths Arreglo de rutas a imágenes (JPG/PNG)
     * @param image_count Cantidad de imágenes (debe ser 5)
     * @param resultado_json Buffer donde se copiara el resultado JSON
     * @param buffer_size Tamaño del buffer de resultado
     * @return 0 si exito, -1 si error
     */
    int oreja_mobile_registrar_biometria(int identificador_unico,
                                         const char **image_paths,
                                         int image_count,
                                         char *resultado_json,
                                         size_t buffer_size);

    // ============================================================================
    // AUTENTICACION
    // ============================================================================

    /**
     * Autenticar usuario por oreja (1:1)
     * @param identificador_claimed ID del usuario a verificar
     * @param image_path Ruta a la imagen (JPG/PNG)
     * @param umbral Umbral de verificacion (si <0, usa umbral_eer.txt o 0.5)
     * @param resultado_json Buffer donde se copiara el resultado JSON
     * @param buffer_size Tamaño del buffer de resultado
     * @return 1 si autenticado, 0 si rechazado, -1 si error
     */
    int oreja_mobile_autenticar(int identificador_claimed,
                                const char *image_path,
                                double umbral,
                                char *resultado_json,
                                size_t buffer_size);

    // ============================================================================
    // UTILIDADES
    // ============================================================================

    /**
     * Obtener ultimo error ocurrido
     * @param buffer Buffer donde se copiara el mensaje de error
     * @param buffer_size Tamaño del buffer
     */
    void oreja_mobile_obtener_ultimo_error(char *buffer, size_t buffer_size);

    /**
     * Obtener estadisticas del modelo
     * @param stats_json Buffer donde se copiara el JSON con estadisticas
     * @param buffer_size Tamaño del buffer
     * @return 0 si exito, -1 si error
     */
    int oreja_mobile_obtener_estadisticas(char *stats_json, size_t buffer_size);

// ============================================================================
// SINCRONIZACION
// ============================================================================

/**
 * Push: enviar vectores pendientes al servidor
 * @param server_url URL del servidor (ej: "http://localhost:8080")
 * @param resultado_json Buffer donde se copiara el resultado JSON
 * @param buffer_size Tamaño del buffer
 * @return 0 si exito, -1 si error
 */
int oreja_mobile_sync_push(const char *server_url, char *resultado_json, size_t buffer_size);

/**
 * Pull: descargar cambios del servidor (usuarios, credenciales)
 * @param server_url URL del servidor
 * @param desde Timestamp desde cuando obtener cambios (opcional, "" para todas)
 * @param resultado_json Buffer donde se copiara el resultado JSON
 * @param buffer_size Tamaño del buffer
 * @return 0 si exito, -1 si error
 */
int oreja_mobile_sync_pull(const char *server_url, const char *desde, char *resultado_json, size_t buffer_size);

/**
 * Pull modelo: descargar archivo del servidor (modelo/umbral/templates)
 * @param server_url URL del servidor
 * @param archivo Nombre del archivo permitido en /oreja/sync/modelo
 * @param resultado_json Buffer donde se copiara el resultado JSON
 * @param buffer_size Tamaño del buffer
 * @return 0 si exito, -1 si error
 */
int oreja_mobile_sync_modelo(const char *server_url, const char *archivo, char *resultado_json, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif // OREJA_MOBILE_API_H
