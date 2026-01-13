# ⚡ CONFIGURACIÓN RÁPIDA - BACKEND POSTGRESQL

## 🎯 PARA TUS COMPAÑEROS DEL BACKEND

### Endpoints Requeridos

El app móvil espera estos endpoints:

#### 1. Health Check
```
GET /api/health
```
Respuesta:
```json
{
  "status": "ok",
  "database": "connected"
}
```

---

#### 2. Registrar Usuario
```
POST /api/usuarios
Content-Type: application/json

{
  "nombres": "Juan",
  "apellidos": "Pérez",
  "fecha_nacimiento": "1990-01-15",
  "sexo": "M",
  "identificador_unico": "juan.perez@email.com"
}
```

Respuesta:
```json
{
  "id_usuario": 123,
  "mensaje": "Usuario creado exitosamente"
}
```

---

#### 3. Registrar Foto de Oreja (Entrenamiento)
```
POST /api/biometria/registrar-oreja
Content-Type: application/json

{
  "id_usuario": 123,
  "imagen_base64": "iVBORw0KGgoAAAANSUhEUgAA...",
  "numero_foto": 1
}
```

**Notas importantes:**
- Se enviarán 3 fotos (numero_foto: 1, 2, 3)
- Imagen ya viene preprocesada: 224×224, RGB, normalizada
- Entrenar modelo cuando llegue la foto 3

Respuesta:
```json
{
  "success": true,
  "mensaje": "Foto 1/3 registrada",
  "id_credencial": 456,
  "total_fotos": 1
}
```

---

#### 4. Verificar Oreja (Login)
```
POST /api/biometria/verificar-oreja
Content-Type: application/json

{
  "id_usuario": 123,
  "imagen_base64": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

**Proceso esperado:**
1. Extraer características de la imagen
2. Comparar con modelo entrenado del usuario
3. Calcular similarity score
4. Retornar verificado=true si score >= 0.75

Respuesta:
```json
{
  "verified": true,
  "confidence": 0.92,
  "mensaje": "Autenticación exitosa"
}
```

O si falla:
```json
{
  "verified": false,
  "confidence": 0.45,
  "mensaje": "No se pudo verificar la identidad"
}
```

---

#### 5. Registrar Audio de Voz (Entrenamiento)
```
POST /api/biometria/registrar-voz
Content-Type: application/json

{
  "id_usuario": 123,
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAA..."
}
```

**Características del audio:**
- Formato: WAV
- Sample rate: 16000 Hz
- Canales: 1 (mono)
- Duración: >= 5 segundos
- Encoding: PCM 16-bit

Respuesta:
```json
{
  "success": true,
  "mensaje": "Audio registrado correctamente",
  "id_credencial": 789
}
```

---

#### 6. Verificar Voz (Login)
```
POST /api/biometria/verificar-voz
Content-Type: application/json

{
  "id_usuario": 123,
  "audio_base64": "UklGRiQAAABXQVZFZm10IBAA..."
}
```

**Proceso esperado:**
1. Extraer características (MFCC, espectrograma)
2. Comparar con modelo entrenado del usuario
3. Calcular similarity score
4. Retornar verificado=true si score >= 0.75

Respuesta:
```json
{
  "verified": true,
  "confidence": 0.88,
  "mensaje": "Autenticación exitosa"
}
```

---

#### 7. Obtener Frase Dinámica (Opcional - Anti-spoofing)
```
GET /api/frases/obtener-activa
```

Respuesta:
```json
{
  "id_texto": 1,
  "frase": "Por favor di: autenticación biométrica dos cuatro siete",
  "estado_texto": "activo"
}
```

---

## 🗄️ ESQUEMA DE BASE DE DATOS

Ya está implementado en PostgreSQL según tu schema.sql:

```sql
-- Usuarios
CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombres VARCHAR(100),
    apellidos VARCHAR(100),
    fecha_nacimiento DATE,
    sexo VARCHAR(10),
    identificador_unico VARCHAR(100) UNIQUE NOT NULL,
    estado VARCHAR(20) DEFAULT 'activo',
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Credenciales Biométricas
CREATE TABLE credenciales_biometricas (
    id_credencial SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    tipo_biometria VARCHAR(20) CHECK (tipo_biometria IN ('oreja', 'voz')),
    fecha_captura TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado VARCHAR(20) DEFAULT 'activo'
);

-- Textos Dinámicos para Voz
CREATE TABLE textos_dinamicos_audio (
    id_texto SERIAL PRIMARY KEY,
    frase TEXT NOT NULL,
    estado_texto VARCHAR(20) DEFAULT 'activo'
);

-- Auditoría de Validaciones
CREATE TABLE validaciones_biometricas (
    id_validacion SERIAL PRIMARY KEY,
    id_usuario INTEGER REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    tipo_biometria VARCHAR(20),
    resultado VARCHAR(10), -- 'exito', 'fallo'
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🧠 PIPELINE DE MACHINE LEARNING

### Para Oreja (Reconocimiento de Imagen)

**Librerías recomendadas (Python):**
- TensorFlow / Keras
- OpenCV
- NumPy
- scikit-learn

**Proceso de Entrenamiento:**

```python
import cv2
import numpy as np
from sklearn.preprocessing import LabelEncoder
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Conv2D, MaxPooling2D, Flatten, Dense

def entrenar_modelo_oreja(id_usuario, imagenes_base64):
    """
    Entrenar modelo de reconocimiento de oreja
    
    Args:
        id_usuario: ID del usuario
        imagenes_base64: Lista de 3 imágenes en base64
    """
    # 1. Decodificar imágenes
    imagenes = []
    for img_b64 in imagenes_base64:
        img_bytes = base64.b64decode(img_b64)
        img_array = np.frombuffer(img_bytes, dtype=np.uint8)
        img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
        imagenes.append(img)
    
    # 2. Preprocesamiento (ya viene 224x224 del app)
    imagenes_proc = []
    for img in imagenes:
        # Convertir a RGB
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        # Normalizar [0, 1]
        img_norm = img_rgb.astype(np.float32) / 255.0
        imagenes_proc.append(img_norm)
    
    # 3. Extraer características con modelo preentrenado
    # Opción 1: Transfer learning (VGG16, ResNet, MobileNet)
    from tensorflow.keras.applications import MobileNetV2
    base_model = MobileNetV2(include_top=False, pooling='avg')
    
    features = []
    for img in imagenes_proc:
        feat = base_model.predict(np.expand_dims(img, axis=0))
        features.append(feat.flatten())
    
    # 4. Guardar features en DB
    # Template del usuario = promedio de las 3 fotos
    template = np.mean(features, axis=0)
    
    # Guardar en tabla adicional (puedes crear):
    # CREATE TABLE templates_oreja (
    #     id_usuario INTEGER PRIMARY KEY,
    #     features BYTEA,  -- features serializadas
    #     modelo_version VARCHAR(20)
    # );
    
    return {
        "success": True,
        "template_size": len(template),
        "modelo_version": "MobileNetV2"
    }

def verificar_oreja(id_usuario, imagen_base64):
    """
    Verificar identidad con oreja
    """
    # 1. Cargar template del usuario de DB
    template_usuario = cargar_template_db(id_usuario)
    
    # 2. Extraer características de imagen de prueba
    img = decodificar_imagen(imagen_base64)
    features_prueba = extraer_features(img)
    
    # 3. Calcular similitud (cosine similarity)
    from sklearn.metrics.pairwise import cosine_similarity
    similarity = cosine_similarity(
        [template_usuario],
        [features_prueba]
    )[0][0]
    
    # 4. Retornar resultado
    verified = similarity >= 0.75
    
    return {
        "verified": verified,
        "confidence": float(similarity)
    }
```

### Para Voz (Reconocimiento de Audio)

**Librerías recomendadas:**
- librosa (extracción MFCC)
- scipy
- scikit-learn
- TensorFlow

**Proceso de Entrenamiento:**

```python
import librosa
import numpy as np
from scipy.spatial.distance import cosine

def entrenar_modelo_voz(id_usuario, audio_base64):
    """
    Entrenar modelo de reconocimiento de voz
    """
    # 1. Decodificar audio WAV
    audio_bytes = base64.b64decode(audio_base64)
    
    # 2. Cargar con librosa
    audio, sr = librosa.load(
        io.BytesIO(audio_bytes),
        sr=16000,  # Sample rate
        mono=True
    )
    
    # 3. Extraer características MFCC
    mfcc = librosa.feature.mfcc(
        y=audio,
        sr=sr,
        n_mfcc=40,  # 40 coeficientes
        n_fft=2048,
        hop_length=512
    )
    
    # 4. Calcular estadísticas (template del usuario)
    mfcc_mean = np.mean(mfcc, axis=1)
    mfcc_std = np.std(mfcc, axis=1)
    
    template = np.concatenate([mfcc_mean, mfcc_std])
    
    # 5. Guardar en DB
    guardar_template_voz_db(id_usuario, template)
    
    return {
        "success": True,
        "template_size": len(template)
    }

def verificar_voz(id_usuario, audio_base64):
    """
    Verificar identidad con voz
    """
    # 1. Cargar template del usuario
    template_usuario = cargar_template_voz_db(id_usuario)
    
    # 2. Extraer características de audio de prueba
    audio = decodificar_audio(audio_base64)
    features_prueba = extraer_mfcc(audio)
    
    # 3. Calcular similitud
    distance = cosine(template_usuario, features_prueba)
    similarity = 1 - distance
    
    # 4. Retornar resultado
    verified = similarity >= 0.75
    
    return {
        "verified": verified,
        "confidence": float(similarity)
    }
```

---

## 🔒 SEGURIDAD

### Recomendaciones:

1. **HTTPS obligatorio en producción**
2. **Validar tamaño de archivos:**
   - Imágenes: max 5 MB
   - Audio: max 10 MB
3. **Rate limiting:** máx 10 requests/minuto por usuario
4. **Autenticación JWT** para endpoints protegidos
5. **Sanitizar inputs** (SQL injection, XSS)

---

## 📊 MÉTRICAS DE RENDIMIENTO

El backend debe ser capaz de:

- **Entrenamiento de oreja:** < 3 segundos (3 fotos)
- **Verificación de oreja:** < 1 segundo
- **Entrenamiento de voz:** < 5 segundos
- **Verificación de voz:** < 2 segundos

---

## 🧪 TESTING

Ejemplos de datos de prueba:

**Usuario:**
```json
{
  "nombres": "Test",
  "apellidos": "Usuario",
  "identificador_unico": "test@example.com"
}
```

**Imagen de prueba (base64):**
```python
# Generar imagen de prueba
from PIL import Image
import base64
import io

img = Image.new('RGB', (224, 224), color='blue')
buffer = io.BytesIO()
img.save(buffer, format='PNG')
img_base64 = base64.b64encode(buffer.getvalue()).decode()
```

---

## ✅ CHECKLIST BACKEND

- [ ] Implementar todos los endpoints listados
- [ ] Configurar CORS para permitir requests del app
- [ ] Implementar pipeline ML para oreja
- [ ] Implementar pipeline ML para voz
- [ ] Configurar PostgreSQL con schema.sql
- [ ] Probar con Postman/curl
- [ ] Medir tiempos de respuesta
- [ ] Configurar logging
- [ ] Deploy en servidor (Heroku/AWS/DigitalOcean)
- [ ] Compartir URL oficial con equipo mobile

---

## 📞 COMUNICACIÓN

**Cuando tengan la URL lista:**

1. Enviar formato: `https://tu-backend.com/api`
2. Compartir documentación de endpoints
3. Coordinar pruebas de integración
4. Validar formato de respuestas

---

¡Listo para integrar! 🚀
