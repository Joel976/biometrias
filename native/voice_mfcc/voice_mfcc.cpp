/**
 * Librería Nativa para Extracción de MFCC (Mel-Frequency Cepstral Coefficients)
 * 
 * Esta librería implementa la extracción de características MFCC de archivos de audio WAV.
 * Los MFCC son ampliamente utilizados en reconocimiento de voz y autenticación por voz.
 * 
 * Autor: Sistema Biométrico
 * Fecha: 2025
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Parámetros de extracción MFCC
#define SAMPLE_RATE 16000
#define FRAME_SIZE 512       // 32ms a 16kHz
#define FRAME_SHIFT 256      // 16ms a 16kHz (50% overlap)
#define NUM_FILTERS 26       // Número de filtros Mel
#define NUM_MFCC 13          // Número de coeficientes MFCC

// Estructura de encabezado WAV
typedef struct {
    char riff[4];           // "RIFF"
    uint32_t fileSize;      // Tamaño del archivo
    char wave[4];           // "WAVE"
    char fmt[4];            // "fmt "
    uint32_t fmtSize;       // Tamaño del chunk fmt
    uint16_t audioFormat;   // Formato de audio (1 = PCM)
    uint16_t numChannels;   // Número de canales
    uint32_t sampleRate;    // Frecuencia de muestreo
    uint32_t byteRate;      // Bytes por segundo
    uint16_t blockAlign;    // Bytes por muestra
    uint16_t bitsPerSample; // Bits por muestra
    char data[4];           // "data"
    uint32_t dataSize;      // Tamaño de los datos de audio
} WavHeader;

/**
 * Conversión de frecuencia a escala Mel
 */
double hzToMel(double hz) {
    return 2595.0 * log10(1.0 + hz / 700.0);
}

/**
 * Conversión de escala Mel a frecuencia
 */
double melToHz(double mel) {
    return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
}

/**
 * Aplicar ventana Hamming a un frame
 */
void applyHammingWindow(double* frame, int frameSize) {
    for (int i = 0; i < frameSize; i++) {
        double windowValue = 0.54 - 0.46 * cos(2.0 * M_PI * i / (frameSize - 1));
        frame[i] *= windowValue;
    }
}

/**
 * Transformada de Fourier Discreta (DFT) simple
 * Retorna magnitud del espectro de potencia
 */
void computePowerSpectrum(double* frame, int frameSize, double* powerSpectrum) {
    int fftSize = frameSize / 2 + 1;
    
    for (int k = 0; k < fftSize; k++) {
        double real = 0.0;
        double imag = 0.0;
        
        for (int n = 0; n < frameSize; n++) {
            double angle = -2.0 * M_PI * k * n / frameSize;
            real += frame[n] * cos(angle);
            imag += frame[n] * sin(angle);
        }
        
        powerSpectrum[k] = (real * real + imag * imag) / frameSize;
    }
}

/**
 * Crear banco de filtros Mel triangulares
 */
double** createMelFilterbank(int numFilters, int fftSize, int sampleRate) {
    double** filterbank = (double**)malloc(numFilters * sizeof(double*));
    for (int i = 0; i < numFilters; i++) {
        filterbank[i] = (double*)calloc(fftSize, sizeof(double));
    }
    
    double melLow = hzToMel(0);
    double melHigh = hzToMel(sampleRate / 2.0);
    double melStep = (melHigh - melLow) / (numFilters + 1);
    
    // Crear puntos centrales de los filtros en escala Mel
    double* melPoints = (double*)malloc((numFilters + 2) * sizeof(double));
    for (int i = 0; i < numFilters + 2; i++) {
        melPoints[i] = melLow + i * melStep;
    }
    
    // Convertir puntos Mel a bins de FFT
    int* fftBins = (int*)malloc((numFilters + 2) * sizeof(int));
    for (int i = 0; i < numFilters + 2; i++) {
        double hz = melToHz(melPoints[i]);
        fftBins[i] = (int)floor((fftSize + 1) * hz / sampleRate);
    }
    
    // Crear filtros triangulares
    for (int i = 0; i < numFilters; i++) {
        int left = fftBins[i];
        int center = fftBins[i + 1];
        int right = fftBins[i + 2];
        
        // Rampa ascendente
        for (int k = left; k < center && k < fftSize; k++) {
            if (center != left) {
                filterbank[i][k] = (double)(k - left) / (center - left);
            }
        }
        
        // Rampa descendente
        for (int k = center; k < right && k < fftSize; k++) {
            if (right != center) {
                filterbank[i][k] = (double)(right - k) / (right - center);
            }
        }
    }
    
    free(melPoints);
    free(fftBins);
    
    return filterbank;
}

/**
 * Aplicar banco de filtros Mel al espectro de potencia
 */
void applyMelFilterbank(double* powerSpectrum, int fftSize, double** filterbank, 
                        int numFilters, double* melEnergies) {
    for (int i = 0; i < numFilters; i++) {
        melEnergies[i] = 0.0;
        for (int k = 0; k < fftSize; k++) {
            melEnergies[i] += powerSpectrum[k] * filterbank[i][k];
        }
        // Aplicar logaritmo (con piso para evitar log(0))
        melEnergies[i] = log(melEnergies[i] + 1e-10);
    }
}

/**
 * Transformada Discreta del Coseno (DCT) para obtener coeficientes MFCC
 */
void computeDCT(double* melEnergies, int numFilters, double* mfcc, int numMfcc) {
    for (int i = 0; i < numMfcc; i++) {
        mfcc[i] = 0.0;
        for (int j = 0; j < numFilters; j++) {
            mfcc[i] += melEnergies[j] * cos(M_PI * i * (j + 0.5) / numFilters);
        }
    }
}

/**
 * Leer archivo WAV y extraer datos de audio PCM16
 */
int16_t* readWavFile(const char* filePath, int* numSamples) {
    FILE* file = fopen(filePath, "rb");
    if (!file) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: No se pudo abrir archivo: %s\n", filePath);
        return NULL;
    }
    
    WavHeader header;
    size_t bytesRead = fread(&header, sizeof(WavHeader), 1, file);
    if (bytesRead != 1) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: No se pudo leer encabezado WAV\n");
        fclose(file);
        return NULL;
    }
    
    // Validar formato WAV
    if (strncmp(header.riff, "RIFF", 4) != 0 || strncmp(header.wave, "WAVE", 4) != 0) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: Archivo no es WAV válido\n");
        fclose(file);
        return NULL;
    }
    
    // Validar formato PCM16
    if (header.audioFormat != 1 || header.bitsPerSample != 16) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: Solo se soporta WAV PCM16\n");
        fclose(file);
        return NULL;
    }
    
    *numSamples = header.dataSize / sizeof(int16_t);
    
    // Leer datos de audio
    int16_t* audioData = (int16_t*)malloc(header.dataSize);
    if (!audioData) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: No se pudo asignar memoria para audio\n");
        fclose(file);
        return NULL;
    }
    
    bytesRead = fread(audioData, 1, header.dataSize, file);
    if (bytesRead != header.dataSize) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: No se pudieron leer datos de audio\n");
        free(audioData);
        fclose(file);
        return NULL;
    }
    
    fclose(file);
    
    printf("[libvoice_mfcc] ✅ Archivo WAV cargado: %d muestras, %d Hz, %d bits\n", 
           *numSamples, header.sampleRate, header.bitsPerSample);
    
    return audioData;
}

/**
 * FUNCIÓN PRINCIPAL: Extraer coeficientes MFCC de un archivo WAV
 * 
 * @param filePath Ruta al archivo WAV (PCM16, 16kHz)
 * @param numCoefficients Puntero donde se almacenará el número de coeficientes extraídos
 * @return Array de doubles con los coeficientes MFCC (promediados sobre todos los frames)
 *         El llamador debe liberar la memoria con free_mfcc()
 */
extern "C" double* compute_voice_mfcc(const char* filePath, int* numCoefficients) {
    printf("[libvoice_mfcc] 🎤 Iniciando extracción de MFCCs para: %s\n", filePath);
    
    // 1. Leer archivo WAV
    int numSamples = 0;
    int16_t* audioData = readWavFile(filePath, &numSamples);
    if (!audioData) {
        *numCoefficients = 0;
        return NULL;
    }
    
    // 2. Crear banco de filtros Mel
    int fftSize = FRAME_SIZE / 2 + 1;
    double** melFilterbank = createMelFilterbank(NUM_FILTERS, fftSize, SAMPLE_RATE);
    
    // 3. Procesar frames y extraer MFCCs
    int numFrames = (numSamples - FRAME_SIZE) / FRAME_SHIFT + 1;
    if (numFrames <= 0) {
        fprintf(stderr, "[libvoice_mfcc] ERROR: Audio muy corto para análisis\n");
        free(audioData);
        *numCoefficients = 0;
        return NULL;
    }
    
    // Acumular MFCCs de todos los frames
    double* mfccSum = (double*)calloc(NUM_MFCC, sizeof(double));
    double* frame = (double*)malloc(FRAME_SIZE * sizeof(double));
    double* powerSpectrum = (double*)malloc(fftSize * sizeof(double));
    double* melEnergies = (double*)malloc(NUM_FILTERS * sizeof(double));
    double* frameMfcc = (double*)malloc(NUM_MFCC * sizeof(double));
    
    int validFrames = 0;
    
    for (int frameIdx = 0; frameIdx < numFrames; frameIdx++) {
        int startIdx = frameIdx * FRAME_SHIFT;
        
        // Extraer frame y normalizar
        for (int i = 0; i < FRAME_SIZE; i++) {
            frame[i] = (double)audioData[startIdx + i] / 32768.0; // Normalizar PCM16
        }
        
        // Aplicar ventana Hamming
        applyHammingWindow(frame, FRAME_SIZE);
        
        // Calcular espectro de potencia
        computePowerSpectrum(frame, FRAME_SIZE, powerSpectrum);
        
        // Aplicar banco de filtros Mel
        applyMelFilterbank(powerSpectrum, fftSize, melFilterbank, NUM_FILTERS, melEnergies);
        
        // Calcular coeficientes MFCC
        computeDCT(melEnergies, NUM_FILTERS, frameMfcc, NUM_MFCC);
        
        // Acumular
        for (int i = 0; i < NUM_MFCC; i++) {
            mfccSum[i] += frameMfcc[i];
        }
        validFrames++;
    }
    
    // Promediar MFCCs
    if (validFrames > 0) {
        for (int i = 0; i < NUM_MFCC; i++) {
            mfccSum[i] /= validFrames;
        }
    }
    
    // Liberar memoria temporal
    free(frame);
    free(powerSpectrum);
    free(melEnergies);
    free(frameMfcc);
    free(audioData);
    
    for (int i = 0; i < NUM_FILTERS; i++) {
        free(melFilterbank[i]);
    }
    free(melFilterbank);
    
    *numCoefficients = NUM_MFCC;
    
    printf("[libvoice_mfcc] ✅ Extraídos %d coeficientes MFCC de %d frames\n", 
           NUM_MFCC, validFrames);
    
    return mfccSum;
}

/**
 * Liberar memoria de coeficientes MFCC
 */
extern "C" void free_mfcc(double* mfccData) {
    if (mfccData) {
        free(mfccData);
    }
}
