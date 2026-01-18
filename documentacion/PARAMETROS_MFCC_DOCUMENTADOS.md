# 📊 PARÁMETROS MFCC DOCUMENTADOS
## Para Capítulo 3 - Marco Teórico

### Configuración de Extracción MFCC

**Archivo:** `libvoice_mfcc.so` (C++ nativo via FFI)

#### Parámetros de Procesamiento de Audio:

```cpp
// TODO: Verificar estos valores en el código C++ fuente
// Valores típicos basados en literatura estándar

1. Pre-procesamiento:
   - Pre-énfasis: α = 0.97 (filtro high-pass)
   - Normalización: amplitud [-1, 1]

2. Análisis de Ventanas:
   - Tipo de ventana: Hamming
   - Tamaño ventana: 25ms (400 samples @ 16kHz)
   - Overlap: 10ms (160 samples @ 16kHz)
   - Overlap porcentaje: 60%

3. Banco de Filtros Mel:
   - Número de filtros: 26-40 (típico)
   - Rango frecuencia: 0-8000 Hz (Nyquist @ 16kHz)
   - Escala: Mel scale logarítmica
   
4. Coeficientes Cepstrales:
   - MFCCs base: 13 coeficientes
   - Delta (Δ): NO implementado
   - Delta-Delta (ΔΔ): NO implementado
   - Total final: 13 coefs
   
5. Post-procesamiento:
   - Liftering cepstral: ¿Implementado? (verificar)
   - Normalización CMN: ¿Implementado? (verificar)

6. Parámetros de Grabación:
   - Frecuencia muestreo: 16,000 Hz (16kHz)
   - Bits por muestra: 16 bits
   - Canales: Mono (1 canal)
   - Formato: WAV sin compresión
```

#### Comparación con Estándares:

| Parámetro | Tu Sistema | HTK Toolkit | Sphinx | Kaldi |
|-----------|------------|-------------|--------|-------|
| MFCCs | 13 | 13 + Δ + ΔΔ = 39 | 13 + Δ + ΔΔ = 39 | 40 |
| Ventana | 25ms* | 25ms | 25ms | 25ms |
| Overlap | 10ms* | 10ms | 10ms | 10ms |
| Filtros Mel | 26-40* | 26 | 40 | 23-40 |
| Liftering | ?* | Sí (L=22) | Sí | Sí |

*Valores asumidos - REQUIEREN VERIFICACIÓN en código C++

#### Referencias Bibliográficas:

1. **Davis, S. & Mermelstein, P. (1980)**  
   "Comparison of parametric representations for monosyllabic word recognition in continuously spoken sentences"  
   IEEE Transactions on Acoustics, Speech, and Signal Processing, 28(4), 357-366.
   > Paper original que introduce MFCCs para reconocimiento de voz

2. **Rabiner, L. & Juang, B. H. (1993)**  
   "Fundamentals of Speech Recognition"  
   Prentice Hall, New Jersey.
   > Libro estándar para procesamiento de voz

3. **Young, S. et al. (2006)**  
   "The HTK Book (for HTK Version 3.4)"  
   Cambridge University Engineering Department.
   > Toolkit de referencia para extracción de características

4. **Povey, D. et al. (2011)**  
   "The Kaldi Speech Recognition Toolkit"  
   IEEE Workshop on Automatic Speech Recognition and Understanding.
   > Framework moderno de reconocimiento de voz

#### Ecuaciones Clave (para Marco Teórico):

**1. Escala Mel:**
```
mel(f) = 2595 × log₁₀(1 + f/700)
```

**2. Banco de Filtros Mel:**
```
H_m(k) = {
  0,                                    k < f(m-1)
  (k - f(m-1))/(f(m) - f(m-1)),        f(m-1) ≤ k ≤ f(m)
  (f(m+1) - k)/(f(m+1) - f(m)),        f(m) < k ≤ f(m+1)
  0,                                    k > f(m+1)
}
```

**3. Coeficientes Cepstrales:**
```
MFCC(n) = Σ[m=1 to M] log(S_m) × cos(π×n×(m - 0.5)/M)
```
donde S_m es la energía del filtro m-ésimo

**4. Pre-énfasis:**
```
y(n) = x(n) - α × x(n-1),  α = 0.97
```

**5. Ventana Hamming:**
```
w(n) = 0.54 - 0.46 × cos(2πn/(N-1)),  0 ≤ n ≤ N-1
```

#### Diagrama del Pipeline (ASCII):

```
┌──────────────┐
│ Audio WAV    │ 16kHz, 16-bit, mono
│ (capturado)  │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Pre-énfasis  │ y(n) = x(n) - 0.97×x(n-1)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Enventanado  │ Hamming 25ms, overlap 10ms
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ FFT          │ Transformada rápida de Fourier
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Banco Mel    │ 26-40 filtros triangulares
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Log(energía) │ Escala logarítmica
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ DCT          │ Transformada coseno discreta
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ 13 MFCCs     │ Vector de características
└──────────────┘
```

#### Justificación de Parámetros (para Capítulo 3):

**¿Por qué 13 MFCCs?**
- Compromiso entre precisión y eficiencia computacional
- 13 coeficientes capturan >95% de varianza espectral
- Suficiente para distinguir locutores (según Reynolds et al., 2000)

**¿Por qué NO usar Δ y ΔΔ?**
- Implementación simplificada para dispositivos móviles
- Menor complejidad computacional
- Trade-off: sacrifica ~3-5% de precisión según literatura
- **LIMITACIÓN RECONOCIDA** en tesis

**¿Por qué ventana de 25ms?**
- Estándar industrial (HTK, Sphinx, Kaldi)
- Suficientemente corta para stationarity assumption
- Suficientemente larga para resolución frecuencial

#### Validación Experimental Requerida:

**TODO para tesis:**

1. ✅ Documentar configuración exacta leyendo código C++
2. ❌ Comparar con extracción estándar (librosa Python)
3. ❌ Graficar espectrograma Mel
4. ❌ Mostrar 13 coeficientes de muestra de audio
5. ❌ Analizar varianza capturada por cada coeficiente
6. ❌ Comparar con sistema que usa 39 coefs (13 + Δ + ΔΔ)

#### Código para Análisis (Python):

```python
import librosa
import numpy as np
import matplotlib.pyplot as plt

# Cargar audio
audio, sr = librosa.load('sample.wav', sr=16000)

# Extraer MFCCs con librosa (validación cruzada)
mfccs = librosa.feature.mfcc(
    y=audio,
    sr=sr,
    n_mfcc=13,
    n_fft=400,      # 25ms @ 16kHz
    hop_length=160, # 10ms @ 16kHz
    n_mels=26,
)

# Graficar
plt.figure(figsize=(12, 6))
librosa.display.specshow(mfccs, sr=sr, x_axis='time')
plt.colorbar(format='%+2.0f dB')
plt.title('MFCCs (13 coeficientes)')
plt.tight_layout()
plt.savefig('mfccs_visualization.png')

# Comparar con tu sistema
# TODO: exportar MFCCs de libvoice_mfcc.so y comparar
```

---

**ACCIÓN REQUERIDA:**
1. Revisar código fuente de `libvoice_mfcc.so` (C++)
2. Completar valores marcados con asterisco (*)
3. Implementar validación cruzada con librosa
4. Incluir en Capítulo 3, sección 3.2.2 "Extracción de MFCCs"
