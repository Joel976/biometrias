# CAPÍTULO I: INTRODUCCIÓN Y ESTADO DEL ARTE

---

## 1.1 Introducción

En la era digital actual, la seguridad de la información y la autenticación de usuarios se han convertido en aspectos críticos para cualquier sistema informático. Los métodos tradicionales de autenticación basados en contraseñas presentan vulnerabilidades significativas, incluyendo la posibilidad de olvido, robo, o interceptación por métodos de ingeniería social. Según estudios recientes, más del 80% de las brechas de seguridad están relacionadas con contraseñas débiles o comprometidas.

La **autenticación biométrica** surge como una alternativa robusta y confiable, utilizando características físicas únicas e irrepetibles de cada individuo. A diferencia de las contraseñas, los rasgos biométricos no pueden ser olvidados, compartidos fácilmente, o transferidos a terceros sin el conocimiento del usuario legítimo.

El presente proyecto desarrolla un **sistema de autenticación biométrica multimodal** que integra tres factores de verificación: **reconocimiento de voz**, **reconocimiento de geometría del oído** (ear recognition), y **validación de contraseña** como respaldo. Esta combinación proporciona múltiples capas de seguridad, aumentando significativamente la dificultad para un acceso no autorizado.

Una característica distintiva de este sistema es su capacidad de **funcionamiento offline**, permitiendo la autenticación de usuarios incluso en ausencia de conectividad a Internet. Esta funcionalidad es crítica en escenarios donde la disponibilidad de red no puede garantizarse, como zonas rurales, dispositivos móviles con conectividad intermitente, o situaciones de emergencia.

El sistema se implementa mediante una **arquitectura híbrida cliente-servidor**, donde una aplicación móvil desarrollada en **Flutter** interactúa con un backend construido en **Node.js** y **PostgreSQL**. La arquitectura permite sincronización bidireccional de datos biométricos, garantizando consistencia entre los registros locales y en la nube.

---

## 1.2 Planteamiento del Problema

### 1.2.1 Problema General

Los sistemas de autenticación tradicionales basados en contraseñas presentan vulnerabilidades críticas que comprometen la seguridad de la información:

- **Contraseñas débiles**: Los usuarios tienden a crear contraseñas fáciles de recordar, lo que las hace susceptibles a ataques de fuerza bruta o diccionario.
- **Reutilización de credenciales**: El uso de la misma contraseña en múltiples servicios amplifica el riesgo de compromiso.
- **Ataques de phishing**: Los usuarios pueden ser engañados para revelar sus credenciales en sitios fraudulentos.
- **Pérdida u olvido**: Las contraseñas complejas son olvidadas con frecuencia, generando costos de soporte y pérdida de productividad.

### 1.2.2 Problemática Específica

En el contexto de aplicaciones móviles, se agregan desafíos adicionales:

1. **Conectividad intermitente**: Muchas aplicaciones requieren conectividad constante para autenticación, lo que limita su uso en áreas con cobertura irregular.

2. **Latencia de red**: La dependencia de servidores remotos introduce retrasos que afectan la experiencia del usuario.

3. **Privacidad de datos biométricos**: El almacenamiento de datos biométricos en servidores centralizados plantea riesgos de privacidad y cumplimiento regulatorio (GDPR, CCPA).

4. **Limitaciones de hardware móvil**: Los dispositivos móviles tienen restricciones de procesamiento y memoria que dificultan la implementación de algoritmos complejos de deep learning.

5. **Falsificación biométrica**: Los sistemas basados en un solo factor biométrico pueden ser vulnerables a ataques de presentación (presentation attacks) o spoofing.

### 1.2.3 Pregunta de Investigación

¿Cómo desarrollar un sistema de autenticación biométrica multimodal que opere eficientemente tanto en modo online como offline, garantizando seguridad, privacidad y usabilidad en dispositivos móviles con recursos limitados?

---

## 1.3 Justificación

### 1.3.1 Justificación Teórica

La investigación contribuye al conocimiento en las siguientes áreas:

1. **Biometría multimodal**: Integración de múltiples modalidades biométricas (voz y geometría del oído) para aumentar la precisión y seguridad del sistema.

2. **Algoritmos de procesamiento de señales**: Desarrollo de técnicas avanzadas de extracción de características para reconocimiento de voz y análisis de imágenes del oído.

3. **Sincronización offline-online**: Diseño de protocolos de sincronización bidireccional que garantizan consistencia de datos entre dispositivos locales y servidores en la nube.

4. **Seguridad en aplicaciones móviles**: Implementación de prácticas de seguridad que protegen datos sensibles tanto en tránsito como en reposo.

### 1.3.2 Justificación Práctica

El sistema desarrollado ofrece ventajas prácticas significativas:

1. **Disponibilidad continua**: El funcionamiento offline garantiza que los usuarios puedan autenticarse incluso sin conexión a Internet.

2. **Reducción de costos de infraestructura**: La validación local reduce la carga en servidores y el consumo de ancho de banda.

3. **Mejora de la experiencia de usuario**: Tiempos de respuesta más rápidos al eliminar la latencia de red en la autenticación.

4. **Flexibilidad de despliegue**: El sistema puede adaptarse a diferentes escenarios de uso, desde aplicaciones bancarias hasta control de acceso físico.

5. **Privacidad mejorada**: Los datos biométricos pueden permanecer en el dispositivo local, reduciendo riesgos de exposición.

### 1.3.3 Justificación Social

El proyecto tiene impacto social en varios aspectos:

1. **Inclusión digital**: Permite acceso a servicios seguros en regiones con infraestructura de red limitada.

2. **Protección de identidad**: Reduce el riesgo de robo de identidad al eliminar la dependencia de contraseñas vulnerables.

3. **Accesibilidad**: La autenticación biométrica simplifica el proceso para usuarios con dificultades para recordar contraseñas complejas, incluyendo adultos mayores.

4. **Cumplimiento normativo**: Facilita el cumplimiento de regulaciones de protección de datos al minimizar la transmisión de información sensible.

---

## 1.4 Alcance

### 1.4.1 Alcance Técnico

El sistema desarrollado abarca:

1. **Modalidades biométricas**:
   - Reconocimiento de voz mediante análisis de patrones espectrales (MFCC)
   - Reconocimiento de geometría del oído mediante extracción de características de imagen
   - Validación de contraseña como factor de respaldo

2. **Plataformas**:
   - Aplicación móvil multiplataforma (Android, iOS, Web) desarrollada en Flutter
   - Backend RESTful desarrollado en Node.js con Express
   - Base de datos PostgreSQL para almacenamiento persistente

3. **Funcionalidades**:
   - Registro de usuarios con captura de datos biométricos
   - Autenticación multimodal con validación de dos o más factores
   - Sincronización bidireccional entre dispositivo local y servidor
   - Gestión de credenciales biométricas (creación, actualización, eliminación)
   - Panel de administración para gestión de usuarios y auditoría

4. **Modos de operación**:
   - **Modo online**: Autenticación mediante servidor con modelos de deep learning
   - **Modo offline**: Autenticación local mediante algoritmos de extracción de características optimizados

### 1.4.2 Alcance Funcional

Las funcionalidades implementadas incluyen:

- **Registro de usuarios**: Captura de al menos 7 muestras de voz y 7 imágenes del oído
- **Login biométrico**: Validación mediante comparación con templates almacenados
- **Sincronización automática**: Actualización de credenciales al restaurar conectividad
- **Gestión de usuarios**: CRUD completo con soft delete y restauración
- **Auditoría**: Registro de eventos de autenticación y modificaciones de datos
- **Seguridad**: Encriptación de datos sensibles, validación de entrada, protección contra inyección SQL

### 1.4.3 Alcance Geográfico

El sistema está diseñado para:

- Operar en cualquier ubicación geográfica con o sin conectividad a Internet
- Soportar múltiples idiomas en la interfaz de usuario (inicialmente español)
- Adaptarse a diferentes condiciones de iluminación y ruido ambiental

### 1.4.4 Alcance Temporal

El desarrollo del proyecto se realizó en las siguientes fases:

1. **Fase 1 - Investigación y diseño** (2 meses)
2. **Fase 2 - Desarrollo del backend** (2 meses)
3. **Fase 3 - Desarrollo de la aplicación móvil** (3 meses)
4. **Fase 4 - Implementación de sincronización offline** (1 mes)
5. **Fase 5 - Pruebas y optimización** (1 mes)
6. **Fase 6 - Documentación y cierre** (1 mes)

---

## 1.5 Limitaciones

### 1.5.1 Limitaciones Técnicas

1. **Capacidad de procesamiento móvil**:
   - Los dispositivos móviles tienen limitaciones de CPU y memoria que impiden el uso de modelos de deep learning complejos en modo offline.
   - Solución implementada: Algoritmos de extracción de características optimizados (512+ dimensiones) que balancean precisión y rendimiento.

2. **Calidad de sensores**:
   - La precisión del reconocimiento biométrico depende de la calidad de la cámara y el micrófono del dispositivo.
   - Variabilidad en condiciones de iluminación y ruido ambiental afecta la captura de datos.

3. **Almacenamiento local**:
   - SQLite en dispositivos móviles tiene limitaciones de tamaño y rendimiento.
   - Se implementó un límite de 7 credenciales por modalidad para optimizar almacenamiento.

4. **Compatibilidad de plataforma**:
   - TensorFlow Lite presenta problemas de compilación en plataformas web.
   - Solución: Uso dual de deep learning en servidor (Python) y algoritmos hand-crafted en cliente (Dart).

### 1.5.2 Limitaciones de Datos

1. **Dataset de entrenamiento**:
   - No se dispone de datasets públicos extensos para reconocimiento de geometría del oído.
   - Los modelos se entrenan con datos capturados específicamente para este proyecto.

2. **Diversidad demográfica**:
   - Las pruebas iniciales se realizan con un grupo limitado de usuarios.
   - Se requiere validación adicional con poblaciones más diversas.

### 1.5.3 Limitaciones de Seguridad

1. **Ataques de presentación**:
   - El sistema no implementa detección de vivacidad (liveness detection) avanzada.
   - Vulnerabilidad potencial a ataques con grabaciones de voz o fotografías del oído.

2. **Ingeniería inversa**:
   - El código de la aplicación móvil podría ser objeto de ingeniería inversa.
   - Mitigación: Ofuscación de código y validación en múltiples capas.

### 1.5.4 Limitaciones Regulatorias

1. **Protección de datos**:
   - El almacenamiento de datos biométricos debe cumplir con regulaciones locales (GDPR, CCPA, leyes nacionales).
   - Se requiere consentimiento explícito del usuario y políticas de privacidad claras.

2. **Jurisdicción**:
   - Las regulaciones sobre datos biométricos varían por país.
   - El sistema debe adaptarse a requisitos legales específicos del contexto de despliegue.

---

## 1.6 Objetivos de la Investigación

### 1.6.1 Objetivo General

Desarrollar e implementar un **sistema de autenticación biométrica multimodal** que integre reconocimiento de voz y geometría del oído, con capacidad de funcionamiento tanto online como offline, garantizando seguridad, privacidad y usabilidad en aplicaciones móviles.

### 1.6.2 Objetivos Específicos

#### Objetivo Específico 1: Diseño de la Arquitectura del Sistema
Diseñar una arquitectura híbrida cliente-servidor que permita:
- Autenticación online mediante modelos de deep learning en el servidor
- Autenticación offline mediante algoritmos de extracción de características en el dispositivo
- Sincronización bidireccional de datos biométricos entre cliente y servidor
- Gestión de estados de conectividad y transiciones entre modos online/offline

**Indicador de cumplimiento**: Diagrama de arquitectura validado y documentado que especifique componentes, interfaces y flujos de datos.

---

#### Objetivo Específico 2: Implementación de Reconocimiento de Voz
Implementar un módulo de reconocimiento de voz que:
- Extraiga características acústicas mediante coeficientes MFCC (Mel-Frequency Cepstral Coefficients)
- Utilice modelos de deep learning (CNN/LSTM) para clasificación en modo online
- Aplique algoritmos de comparación de vectores de características en modo offline
- Valide frases aleatorias para prevenir ataques de reproducción

**Indicador de cumplimiento**: Módulo de reconocimiento de voz con precisión superior al 90% en condiciones controladas y superior al 80% en condiciones de ruido moderado.

---

#### Objetivo Específico 3: Implementación de Reconocimiento de Geometría del Oído
Desarrollar un módulo de reconocimiento del oído que:
- Capture imágenes del oído con calidad óptima (ResolutionPreset.max)
- Extraiga características discriminantes mediante algoritmos avanzados (LBP, DCT, Edge Density Map, Autocorrelación)
- Genere embeddings de 512+ dimensiones para comparación robusta
- Rechace imágenes de partes del cuerpo incorrectas (cara, mano, objetos aleatorios)

**Indicador de cumplimiento**: Módulo de reconocimiento del oído con tasa de aceptación falsa (FAR) inferior al 5% y tasa de rechazo falso (FRR) inferior al 10%.

---

#### Objetivo Específico 4: Desarrollo de Mecanismo de Sincronización Offline
Implementar un sistema de sincronización que:
- Detecte automáticamente cambios de estado de conectividad
- Sincronice credenciales biométricas del servidor al dispositivo al restaurar conexión
- Envíe credenciales creadas localmente al servidor
- Gestione conflictos de sincronización mediante banderas de estado
- Implemente límites de almacenamiento (máximo 7 credenciales por modalidad)

**Indicador de cumplimiento**: Sistema de sincronización funcional que garantice consistencia de datos con conflictos resueltos correctamente en el 100% de los casos de prueba.

---

#### Objetivo Específico 5: Optimización de Algoritmos para Dispositivos Móviles
Optimizar los algoritmos de procesamiento biométrico para:
- Reducir el tiempo de procesamiento a menos de 2 segundos por autenticación
- Minimizar el consumo de memoria (footprint inferior a 100MB)
- Garantizar compatibilidad multiplataforma (Android, iOS, Web)
- Balancear precisión y rendimiento mediante técnicas de feature engineering

**Indicador de cumplimiento**: Tiempos de respuesta medidos en dispositivos de gama media que cumplan con los umbrales especificados en el 95% de las pruebas.

---

#### Objetivo Específico 6: Implementación de Medidas de Seguridad
Incorporar mecanismos de seguridad que:
- Encripten datos biométricos en reposo (AES-256)
- Protejan la comunicación mediante HTTPS/TLS
- Validen y sanitizen todas las entradas del usuario
- Implementen rate limiting para prevenir ataques de fuerza bruta
- Registren eventos de auditoría para análisis forense

**Indicador de cumplimiento**: Sistema que pase pruebas de penetración básicas (OWASP Top 10) y auditoría de seguridad sin vulnerabilidades críticas.

---

#### Objetivo Específico 7: Desarrollo de Interfaz de Usuario Intuitiva
Crear una interfaz de usuario que:
- Guíe al usuario en el proceso de registro y autenticación
- Proporcione retroalimentación visual y auditiva en tiempo real
- Sea accesible para usuarios con diferentes niveles de alfabetización tecnológica
- Cumpla con principios de diseño Material Design
- Funcione correctamente en diferentes tamaños de pantalla

**Indicador de cumplimiento**: Interfaz de usuario validada mediante pruebas de usabilidad con al menos 10 usuarios, obteniendo una puntuación SUS (System Usability Scale) superior a 70.

---

#### Objetivo Específico 8: Validación y Pruebas del Sistema
Realizar pruebas exhaustivas que incluyan:
- Pruebas unitarias con cobertura superior al 70%
- Pruebas de integración de todos los módulos
- Pruebas de rendimiento (stress testing, load testing)
- Pruebas de seguridad (penetration testing)
- Pruebas de usabilidad con usuarios reales

**Indicador de cumplimiento**: Suite de pruebas completa ejecutada exitosamente con tasas de éxito superiores al 95% en todas las categorías.

---

## 1.7 Estado del Arte

### 1.7.1 Autenticación Biométrica: Fundamentos

La autenticación biométrica se basa en el reconocimiento de características físicas o comportamentales únicas de los individuos. Jain et al. (2004) clasifican los sistemas biométricos en:

1. **Biometría fisiológica**: Basada en características físicas (huella dactilar, iris, rostro, geometría del oído, ADN).
2. **Biometría comportamental**: Basada en patrones de comportamiento (voz, firma, dinámica de escritura en teclado, marcha).

Un sistema biométrico típico consta de cinco módulos principales:
- **Captura**: Adquisición de datos biométricos mediante sensores
- **Extracción de características**: Procesamiento de datos para obtener representación compacta
- **Almacenamiento**: Persistencia de templates biométricos
- **Comparación**: Cálculo de similitud entre template capturado y almacenado
- **Decisión**: Clasificación como genuino o impostor basada en umbral

### 1.7.2 Reconocimiento de Voz

#### Fundamentos Técnicos

El reconocimiento de voz para autenticación biométrica se basa en la extracción de características acústicas que reflejan propiedades físicas únicas del tracto vocal de cada individuo.

**Coeficientes MFCC (Mel-Frequency Cepstral Coefficients)**:
- Desarrollados por Davis y Mermelstein (1980), los MFCC son la representación estándar en reconocimiento de voz.
- Modelan la percepción no lineal del oído humano mediante la escala Mel.
- Típicamente se extraen 13-20 coeficientes por ventana de análisis (20-40ms).

**Arquitecturas de Deep Learning**:
- **CNN (Convolutional Neural Networks)**: Utilizadas para extraer características espaciales de espectrogramas (Amodei et al., 2016).
- **LSTM (Long Short-Term Memory)**: Capturan dependencias temporales en secuencias de audio (Graves et al., 2013).
- **Transformer**: Arquitecturas de atención para modelado de secuencias (Vaswani et al., 2017).

#### Trabajos Previos Relevantes

1. **Nagrani et al. (2017)** - "VoxCeleb: A large-scale speaker identification dataset"
   - Dataset con más de 100,000 utterances de 1,251 celebridades
   - Precisión del 95.3% con redes ResNet-34

2. **Snyder et al. (2018)** - "X-vectors: Robust DNN embeddings for speaker recognition"
   - Embeddings de dimensión fija independientes de la duración del audio
   - State-of-the-art en reconocimiento de locutor

3. **Chung et al. (2020)** - "In defence of metric learning for speaker recognition"
   - Uso de triplet loss para aprendizaje de embeddings discriminativos
   - Mejora de 15% en EER (Equal Error Rate) sobre baseline

### 1.7.3 Reconocimiento de Geometría del Oído

#### Fundamentos y Motivación

El reconocimiento del oído como modalidad biométrica fue propuesto por Iannarelli (1989), quien documentó que la estructura del oído externo es única para cada individuo y permanece relativamente estable a lo largo de la vida adulta.

**Ventajas del reconocimiento del oído**:
- No requiere contacto físico
- Menos susceptible a cambios por expresiones faciales
- Puede capturarse a distancia
- Alta estabilidad temporal

#### Técnicas de Extracción de Características

1. **Métodos basados en geometría**:
   - Burge y Burger (2000): Análisis de curvas y detección de bordes del oído
   - Hurley et al. (2005): Force field transformation para representación invariante a rotación

2. **Métodos basados en apariencia**:
   - **PCA (Principal Component Analysis)**: Reducción de dimensionalidad lineal
   - **LDA (Linear Discriminant Analysis)**: Maximiza separabilidad entre clases
   - **ICA (Independent Component Analysis)**: Extracción de componentes estadísticamente independientes

3. **Métodos basados en características locales**:
   - **LBP (Local Binary Patterns)**: Ojala et al. (2002) - Descriptores de textura robustos
   - **SIFT (Scale-Invariant Feature Transform)**: Lowe (2004) - Keypoints invariantes a escala
   - **HOG (Histogram of Oriented Gradients)**: Dalal y Triggs (2005) - Descriptores de forma

4. **Deep Learning**:
   - Emeršič et al. (2017): CNN para reconocimiento del oído con dataset AWE (Annotated Web Ears)
   - Zhang et al. (2019): Siamese Networks para verificación one-shot
   - Earnest et al. (2020): EarNet - Arquitectura especializada con atención

#### Trabajos Previos Relevantes

1. **Emeršič et al. (2017)** - "The unconstrained ear recognition challenge"
   - Dataset AWE con 1,000 sujetos
   - Precisión del 60% en condiciones no controladas con CNN

2. **Alshazly et al. (2019)** - "Ear recognition using deep learning: A survey"
   - Revisión exhaustiva de métodos basados en deep learning
   - Identificación de desafíos: oclusión, iluminación, pose

3. **Dodge et al. (2018)** - "Unconstrained ear recognition using deep neural networks"
   - Transfer learning desde modelos pre-entrenados (VGG, ResNet)
   - Rank-1 accuracy del 93.4% en dataset IIT Delhi

### 1.7.4 Sistemas Biométricos Multimodales

#### Motivación y Fundamentos

Los sistemas multimodales combinan múltiples fuentes de información biométrica para mejorar precisión y robustez. Ross y Jain (2003) identifican ventajas clave:

1. **Reducción de FAR y FRR**: Combinación de evidencias reduce errores
2. **Resistencia a spoofing**: Falsificar múltiples modalidades es más difícil
3. **Mayor cobertura poblacional**: Alternativas si una modalidad falla

#### Niveles de Fusión

1. **Fusión a nivel de sensor**: Combinación de datos crudos
2. **Fusión a nivel de características**: Concatenación de feature vectors
3. **Fusión a nivel de scores**: Combinación de scores de similitud (más común)
4. **Fusión a nivel de decisión**: Votación entre decisiones individuales

#### Estrategias de Fusión

- **Suma ponderada**: `S_fusion = w1*S1 + w2*S2 + ... + wn*Sn`
- **Producto**: `S_fusion = S1 * S2 * ... * Sn`
- **Mínimo/Máximo**: `S_fusion = min(S1, S2, ..., Sn)`
- **Machine Learning**: SVM, Random Forest para aprender fusión óptima

#### Trabajos Previos Relevantes

1. **Ross y Jain (2003)** - "Information fusion in biometrics"
   - Comparación de estrategias de fusión
   - Fusión de scores supera a fusión de decisiones

2. **Kittler et al. (1998)** - "On combining classifiers"
   - Análisis teórico de reglas de combinación
   - Sum rule muestra buen balance robustez/precisión

3. **Snelick et al. (2005)** - "Large-scale evaluation of multimodal biometric authentication"
   - Evaluación con 517 usuarios
   - Mejora de 10-20x en EER con multimodalidad

### 1.7.5 Autenticación Offline en Dispositivos Móviles

#### Desafíos y Soluciones

Los dispositivos móviles presentan restricciones que requieren adaptaciones:

1. **Limitaciones de procesamiento**:
   - **Problema**: Modelos de deep learning son computacionalmente intensivos
   - **Solución**: Cuantización, pruning, knowledge distillation
   - **Alternativa**: Algoritmos hand-crafted optimizados

2. **Limitaciones de almacenamiento**:
   - **Problema**: Templates biométricos consumen espacio
   - **Solución**: Compresión de vectores de características
   - **Implementación**: Límite de credenciales almacenadas localmente

3. **Seguridad**:
   - **Problema**: Dispositivo puede ser comprometido
   - **Solución**: Trusted Execution Environment (TEE), Secure Enclave
   - **Implementación**: Encriptación de templates en SQLite

#### Trabajos Previos Relevantes

1. **Howard et al. (2017)** - "MobileNets: Efficient CNNs for mobile vision applications"
   - Redes neuronales optimizadas para móviles
   - Trade-off entre precisión y latencia

2. **Sandler et al. (2018)** - "MobileNetV2: Inverted residuals and linear bottlenecks"
   - Mejora de eficiencia con inverted residuals
   - Reducción de 50% en operaciones vs MobileNetV1

3. **Ignatov et al. (2018)** - "AI Benchmark: Running deep neural networks on Android smartphones"
   - Benchmark de rendimiento en 40+ smartphones
   - Variabilidad de 10x en velocidad de inferencia

### 1.7.6 Sincronización de Datos Offline-Online

#### Estrategias de Sincronización

1. **Full Synchronization**: Transferencia completa de base de datos
   - **Ventaja**: Simple de implementar
   - **Desventaja**: Ineficiente para grandes volúmenes

2. **Delta Synchronization**: Solo cambios desde última sincronización
   - **Ventaja**: Eficiente en ancho de banda
   - **Desventaja**: Requiere tracking de cambios

3. **Conflict-Free Replicated Data Types (CRDTs)**:
   - **Ventaja**: Convergencia eventual garantizada
   - **Desventaja**: Mayor complejidad de implementación

#### Trabajos Previos Relevantes

1. **Satyanarayanan et al. (2001)** - "Coda: A highly available file system for a distributed workstation environment"
   - Sistema de archivos con soporte offline
   - Detección y resolución de conflictos

2. **Terry et al. (1995)** - "Managing update conflicts in Bayou, a weakly connected replicated storage system"
   - Sincronización eventual con resolución de conflictos
   - Logs de operaciones para replay

3. **Shapiro et al. (2011)** - "Conflict-free replicated data types"
   - Fundamentos teóricos de CRDTs
   - Garantía de convergencia sin coordinación

### 1.7.7 Frameworks y Tecnologías Utilizadas

#### Flutter

- **Descripción**: Framework de Google para desarrollo multiplataforma
- **Ventajas**: 
  - Mismo código para Android, iOS, Web, Desktop
  - Rendimiento nativo mediante compilación a código máquina
  - Hot reload para desarrollo rápido
- **Uso en el proyecto**: Desarrollo de aplicación móvil con interfaz Material Design

#### Node.js y Express

- **Descripción**: Runtime de JavaScript para backend + framework web
- **Ventajas**:
  - Event-driven, non-blocking I/O (alta concurrencia)
  - Ecosistema NPM extenso
  - JavaScript full-stack
- **Uso en el proyecto**: API RESTful para gestión de usuarios y credenciales biométricas

#### PostgreSQL

- **Descripción**: Sistema de gestión de bases de datos relacional open-source
- **Ventajas**:
  - ACID compliance (atomicidad, consistencia, aislamiento, durabilidad)
  - Soporte JSON para datos semi-estructurados
  - Extensible con tipos de datos personalizados
- **Uso en el proyecto**: Almacenamiento de usuarios, credenciales, embeddings, auditoría

#### Python y TensorFlow

- **Descripción**: Lenguaje de programación + framework de deep learning
- **Ventajas**:
  - Ecosistema científico maduro (NumPy, SciPy, scikit-learn)
  - TensorFlow/Keras para modelos de deep learning
  - Rendimiento optimizado con GPU
- **Uso en el proyecto**: Entrenamiento de modelos CNN/LSTM para reconocimiento de voz y oído

### 1.7.8 Brechas en el Estado del Arte

A pesar de los avances significativos en autenticación biométrica, existen brechas que este proyecto aborda:

1. **Falta de sistemas multimodales voz+oído**:
   - La mayoría de investigaciones se centran en modalidades individuales
   - Pocos sistemas integran voz y geometría del oído
   - **Contribución**: Sistema híbrido con fusión de scores

2. **Limitada capacidad offline en aplicaciones móviles**:
   - Sistemas comerciales (Face ID, Touch ID) funcionan localmente pero son propietarios
   - Soluciones académicas raramente abordan sincronización offline-online
   - **Contribución**: Protocolo de sincronización bidireccional con gestión de conflictos

3. **Algoritmos no optimizados para restricciones móviles**:
   - Modelos de deep learning requieren recursos significativos
   - Alternativas hand-crafted carecen de precisión competitiva
   - **Contribución**: Algoritmo de 512+ dimensiones con técnicas avanzadas (LBP, DCT, autocorrelación)

4. **Ausencia de datasets públicos para oído en condiciones no controladas**:
   - Datasets existentes (AMI, USTB, IIT Delhi) son limitados o controlados
   - **Contribución**: Metodología de captura y procesamiento para condiciones reales

5. **Poca atención a usabilidad en sistemas biométricos**:
   - Muchos prototipos académicos descuidan interfaz de usuario
   - **Contribución**: Interfaz intuitiva con retroalimentación en tiempo real y guías visuales

### 1.7.9 Posicionamiento del Proyecto

El presente proyecto se posiciona en la intersección de:
- **Biometría multimodal aplicada** (fusión voz + oído)
- **Computación móvil offline** (edge computing)
- **Ingeniería de software práctica** (sistema completo desplegable)

Contribuciones clave:
1. Sistema end-to-end funcional (no solo prototipo académico)
2. Balanceo entre precisión y recursos computacionales
3. Arquitectura híbrida que maximiza disponibilidad
4. Código abierto y documentación extensiva para reproducibilidad

---

## Referencias Bibliográficas

1. Amodei, D., et al. (2016). Deep speech 2: End-to-end speech recognition in English and Mandarin. *International Conference on Machine Learning*.

2. Alshazly, H., et al. (2019). Ear recognition using deep learning: A survey. *arXiv preprint arXiv:1910.05459*.

3. Burge, M., & Burger, W. (2000). Ear biometrics in computer vision. *Proceedings 15th International Conference on Pattern Recognition*.

4. Chung, J. S., et al. (2020). In defence of metric learning for speaker recognition. *arXiv preprint arXiv:2003.11982*.

5. Dalal, N., & Triggs, B. (2005). Histograms of oriented gradients for human detection. *IEEE Computer Society Conference on Computer Vision and Pattern Recognition*.

6. Davis, S., & Mermelstein, P. (1980). Comparison of parametric representations for monosyllabic word recognition in continuously spoken sentences. *IEEE Transactions on Acoustics, Speech, and Signal Processing*, 28(4), 357-366.

7. Dodge, S., et al. (2018). Unconstrained ear recognition using deep neural networks. *IET Biometrics*, 7(3), 207-214.

8. Earnest, S., et al. (2020). EarNet: Deep learning for ear recognition. *IEEE Access*, 8, 128678-128689.

9. Emeršič, Ž., et al. (2017). The unconstrained ear recognition challenge. *IEEE International Joint Conference on Biometrics*.

10. Graves, A., et al. (2013). Speech recognition with deep recurrent neural networks. *IEEE International Conference on Acoustics, Speech and Signal Processing*.

11. Howard, A. G., et al. (2017). MobileNets: Efficient convolutional neural networks for mobile vision applications. *arXiv preprint arXiv:1704.04861*.

12. Hurley, D. J., et al. (2005). Force field feature extraction for ear biometrics. *Computer Vision and Image Understanding*, 98(3), 491-512.

13. Iannarelli, A. (1989). *Ear identification*. Forensic Identification Series. Paramount Publishing Company.

14. Ignatov, A., et al. (2018). AI benchmark: Running deep neural networks on Android smartphones. *European Conference on Computer Vision Workshops*.

15. Jain, A. K., et al. (2004). An introduction to biometric recognition. *IEEE Transactions on Circuits and Systems for Video Technology*, 14(1), 4-20.

16. Kittler, J., et al. (1998). On combining classifiers. *IEEE Transactions on Pattern Analysis and Machine Intelligence*, 20(3), 226-239.

17. Lowe, D. G. (2004). Distinctive image features from scale-invariant keypoints. *International Journal of Computer Vision*, 60(2), 91-110.

18. Nagrani, A., et al. (2017). VoxCeleb: A large-scale speaker identification dataset. *arXiv preprint arXiv:1706.08612*.

19. Ojala, T., et al. (2002). Multiresolution gray-scale and rotation invariant texture classification with local binary patterns. *IEEE Transactions on Pattern Analysis and Machine Intelligence*, 24(7), 971-987.

20. Ross, A., & Jain, A. (2003). Information fusion in biometrics. *Pattern Recognition Letters*, 24(13), 2115-2125.

21. Sandler, M., et al. (2018). MobileNetV2: Inverted residuals and linear bottlenecks. *IEEE Conference on Computer Vision and Pattern Recognition*.

22. Satyanarayanan, M., et al. (2001). Coda: A highly available file system for a distributed workstation environment. *IEEE Transactions on Computers*, 39(4), 447-459.

23. Shapiro, M., et al. (2011). Conflict-free replicated data types. *Symposium on Self-Stabilizing Systems*.

24. Snelick, R., et al. (2005). Large-scale evaluation of multimodal biometric authentication using state-of-the-art systems. *IEEE Transactions on Pattern Analysis and Machine Intelligence*, 27(3), 450-455.

25. Snyder, D., et al. (2018). X-vectors: Robust DNN embeddings for speaker recognition. *IEEE International Conference on Acoustics, Speech and Signal Processing*.

26. Terry, D. B., et al. (1995). Managing update conflicts in Bayou, a weakly connected replicated storage system. *ACM Symposium on Operating Systems Principles*.

27. Vaswani, A., et al. (2017). Attention is all you need. *Advances in Neural Information Processing Systems*.

28. Zhang, Y., et al. (2019). Ear recognition using Siamese networks. *International Conference on Biometrics*.

---

**Fin del Capítulo I**
