# 🍃 Aerthys — Reconocimiento visual de líquenes con Apple Vision

Aerthys es una aplicación iOS desarrollada como apoyo tecnológico para un proyecto estudiantil de investigación sobre **líquenes como bioindicadores ambientales**, presentado por estudiantes de 4.º de secundaria de la **I.E. Santa Rosa 6094 de Chorrillos, Lima**, en el concurso **EUREKA 2026**.

La aplicación utiliza la cámara del iPhone y herramientas nativas de visión computacional de Apple para comparar una muestra fotografiada con un conjunto de referencias previamente calibradas.

El objetivo técnico de Aerthys no es medir directamente la contaminación del aire ni realizar análisis químicos. Su propósito es demostrar cómo puede construirse, completamente on-device, un sistema de reconocimiento visual basado en referencias capaz de:

- reconocer tres grupos visuales previamente definidos;
- distinguir entre **LOW**, **MODERATE** y **HIGH**;
- rechazar imágenes que no se parecen suficientemente a las referencias conocidas;
- funcionar sin conexión a Internet;
- mantener un flujo simple y repetible para una demostración presencial.

> **Importante:** Aerthys es una demostración tecnológica de reconocimiento visual. No es un instrumento científico de medición ambiental, no detecta metales pesados y no reemplaza análisis de laboratorio ni estaciones certificadas de calidad del aire.

---

## Tecnologías usadas

- Swift
- SwiftUI
- AVFoundation
- Apple Vision
- `VNGenerateImageFeaturePrintRequest`
- `VNFeaturePrintObservation`
- CoreGraphics
- ImageIO
- UIKit para procesamiento de imágenes
- CryptoKit
- XCTest
- XcodeGen
- Procesamiento 100 % on-device
- Sin dependencias externas de terceros

---

## El contexto del proyecto

Aerthys nació a partir de una necesidad concreta.

Un grupo de estudiantes estaba desarrollando para **EUREKA 2026** una propuesta relacionada con el uso de líquenes como bioindicadores naturales. Como parte del proyecto surgió la idea de complementar la investigación con una aplicación móvil capaz de observar las muestras y producir una clasificación visual sencilla durante la demostración.

La aplicación debía cumplir varias condiciones:

- ser rápida y fácil de utilizar;
- funcionar sin Internet;
- utilizar un dispositivo disponible durante la exposición;
- ejecutar el procesamiento directamente en el iPhone;
- reconocer de forma consistente las muestras del proyecto;
- evitar entregar una categoría válida cuando la cámara apunta a un objeto que no corresponde.

Ese último requisito terminó siendo uno de los puntos técnicos más importantes del desarrollo.

Un sistema que siempre devuelve una categoría, incluso frente a una mano, una pared o cualquier objeto desconocido, no era suficiente. Por eso Aerthys no solo intenta reconocer una muestra: **también puede rechazar una captura cuando no encuentra suficiente similitud con sus referencias conocidas**.

---

## Qué hace Aerthys

La aplicación trabaja con tres grupos de referencia:

- **LOW**
- **MODERATE**
- **HIGH**

El flujo de uso es sencillo:

1. La muestra se coloca sobre un fondo blanco mate.
2. Se centra dentro del área de análisis.
3. El usuario inicia el escaneo.
4. Aerthys captura una fotografía real al finalizar la animación de escaneo.
5. Se procesa una región central de la imagen.
6. Apple Vision genera una representación visual de la captura.
7. Esa representación se compara con las referencias almacenadas en la aplicación.
8. Los vecinos visualmente más cercanos votan por una categoría.
9. Se calcula además una distancia de rechazo.
10. Si la similitud es suficiente, se muestra **LOW**, **MODERATE** o **HIGH**.
11. Si no existe suficiente similitud, la captura se rechaza y se solicita repetir.

Cuando una imagen no corresponde suficientemente con las referencias conocidas, la aplicación muestra:

> **No se reconoció la muestra.**

Esto representa de forma más honesta el alcance del sistema que forzar una clasificación.

---

## Flujo de la aplicación

```text
Camera
  ↓
Detecting
  ↓
Scanning
  ↓
Analyzing
  ↓
Result
```

o, si la imagen no supera el criterio de similitud:

```text
Analyzing
  ↓
Rejected
  ↓
Retry
```

Los estados `Detecting` y `Scanning` forman parte de la experiencia visual. La captura fotográfica real ocurre al finalizar el estado de escaneo.

---

## Pipeline de reconocimiento

```text
Camera Capture
      ↓
Centered ROI
      ↓
Image Preprocessing
      ↓
Vision Feature Print
      ↓
Reference Distance Comparison
      ↓
5-Nearest Neighbors
      ↓
Class Vote
      ↓
Rejection Score
      ↓
Calibrated Threshold
      ↓
LOW / MODERATE / HIGH / REJECTED
```

La implementación actual utiliza:

- `VNGenerateImageFeaturePrintRequest`
- Feature Print Revision 1
- `VNFeaturePrintObservation`
- comparación de distancias visuales
- 5 vecinos más cercanos para la votación
- promedio de las 3 distancias más próximas de la clase ganadora como `rejectScore`
- threshold calibrado de `18.379`

El threshold pertenece exclusivamente al conjunto de referencias actual. No es un valor universal reutilizable sin una nueva calibración.

---

## Reconocimiento por similitud

Aerthys no intenta identificar cualquier especie de líquen.

La pregunta técnica que resuelve es más concreta:

> **¿La imagen capturada se parece suficientemente a alguno de los grupos visuales que Aerthys conoce?**

Vision genera un **Feature Print** de la imagen. Puede entenderse como una representación numérica de sus características visuales.

Después, Aerthys calcula la distancia entre el Feature Print de la captura y los Feature Prints de las referencias conocidas.

Cuanto menor es la distancia, mayor es la similitud visual.

---

## 5-NN y decisión de categoría

Una vez calculadas las distancias contra las referencias, Aerthys toma los **5 vecinos visualmente más cercanos**.

Esos vecinos votan entre:

```text
LOW
MODERATE
HIGH
```

La categoría con más votos se convierte en la candidata.

Después se calcula el promedio de las **3 distancias más cercanas pertenecientes a la clase ganadora**.

Ese valor funciona como `rejectScore`.

```text
rejectScore <= 18.379  →  ACCEPTED
rejectScore > 18.379   →  REJECTED
```

Esta segunda comprobación evita que el sistema clasifique obligatoriamente una imagen desconocida.

---

## Por qué el rechazo es importante

En un sistema de reconocimiento visual controlado, equivocarse no es el único problema.

También puede ser un problema **responder con demasiada seguridad cuando la imagen no pertenece a ninguna referencia conocida**.

Si la cámara apunta a:

- una mano;
- una mesa;
- una pared;
- otro objeto;
- una muestra demasiado diferente;

Aerthys debe poder responder que no reconoce la entrada.

Ese comportamiento es deliberado y forma parte del diseño técnico de la aplicación.

---

## El conjunto de referencias

Aerthys incluye actualmente **49 imágenes de referencia**:

| Categoría | Referencias |
|---|---:|
| LOW | 18 |
| MODERATE | 18 |
| HIGH | 13 |
| **Total** | **49** |

Las referencias fueron preparadas bajo condiciones controladas utilizando un **fondo blanco mate**.

La región de análisis utiliza:

```text
cropFraction = 0.82
```

Esto permite conservar suficiente información de la muestra, el recipiente y su contexto inmediato para obtener comparaciones más consistentes.

---

## Por qué se utiliza un fondo blanco

Durante las pruebas físicas se observó que el entorno podía modificar significativamente la representación visual de una misma muestra.

Variables como:

- color de la superficie;
- textura del fondo;
- objetos cercanos;
- reflejos;
- iluminación;
- distancia;
- ángulo;

podían introducir diferencias innecesarias.

La solución fue convertir el fondo blanco mate en parte del protocolo de captura.

Por eso el fondo no es solamente una elección estética: **forma parte de las condiciones controladas bajo las que se calibró el sistema actual**.

---

## Cómo está organizado el proyecto

Aerthys utiliza SwiftUI con una organización ligera basada en MVVM y responsabilidades específicas.

```text
Aerthys/
├── App/
├── Features/
│   ├── Camera/
│   ├── Scanner/
│   ├── Matching/
│   ├── Result/
│   ├── Info/
│   └── Components/
├── Models/
└── Resources/
```

Los tests se encuentran en:

```text
AerthysTests/
```

Las herramientas utilizadas para preparar y calibrar referencias se encuentran en:

```text
tools/
```

La documentación técnica adicional está en:

```text
docs/
```

---

## Componentes principales

### `CameraService`

Gestiona `AVCaptureSession`, la cámara trasera, la captura fotográfica y el torch del dispositivo.

La integración se realiza directamente con AVFoundation.

### `ScannerViewModel`

Controla la máquina de estados principal de la experiencia:

```text
.camera
.detecting
.scanning
.analyzing
.result
```

y el estado de rechazo:

```text
.noLichen
```

### `ImagePreprocessor`

Prepara la imagen antes del análisis.

Aplica la región central de interés y el manejo necesario de orientación.

### `AerthysReferenceMatcher`

Genera el Feature Print de la captura y calcula las distancias visuales contra las referencias empaquetadas utilizando Apple Vision.

### `AerthysMatchDecision`

Recibe las distancias y aplica:

- votación 5-NN;
- selección de clase;
- cálculo del `rejectScore`;
- aceptación o rechazo mediante threshold.

### `AirQualityAssessment`

Convierte las clases internas de referencia en los estados **LOW**, **MODERATE** y **HIGH** mostrados en la interfaz.

Estos estados son categorías visuales de la demostración y no mediciones químicas directas.

---

## Caché de referencias

Calcular repetidamente los Feature Prints de las 49 referencias sería innecesario.

Por eso Aerthys:

- prepara las representaciones de referencia;
- las conserva en memoria durante la ejecución;
- utiliza un caché best-effort en disco;
- invalida el caché cuando cambia la revisión de Vision o el fingerprint del manifest de referencias.

El objetivo es evitar trabajo repetido sin comprometer la posibilidad de actualizar el conjunto de referencias.

---

## Funcionamiento offline

Todo el pipeline se ejecuta directamente en el iPhone.

Aerthys no necesita:

- servidor;
- API;
- conexión de red;
- servicio remoto de Machine Learning;
- almacenamiento en la nube;
- librerías externas de terceros.

La fotografía utilizada para el análisis tampoco se envía a servicios externos.

---

## Calibración

Con el conjunto controlado actual se obtuvieron los siguientes resultados durante la calibración leave-one-out:

| Categoría | Resultado |
|---|---:|
| LOW | 18 / 18 |
| MODERATE | 18 / 18 |
| HIGH | 13 / 13 |
| **Global** | **49 / 49** |

Durante la calibración del rechazo también se obtuvo separación completa entre las referencias conocidas y las imágenes negativas utilizadas para ese proceso.

Valores del conjunto final:

```text
Maximum reference reject score: 15.773
Minimum global "other" score: 20.984
Margin: +5.211
Threshold: 18.379
```

Estos resultados deben interpretarse correctamente:

**no representan una precisión universal del 100 %.**

Describen únicamente el comportamiento del conjunto controlado utilizado durante esta calibración.

Más detalles:

[`docs/calibration.md`](docs/calibration.md)

---

## Evolución de la solución técnica

La solución final no fue la primera aproximación explorada.

Durante una etapa inicial del proyecto se experimentó con clasificación de imágenes utilizando herramientas de Machine Learning de Apple.

Las pruebas con las muestras físicas mostraron que el problema real requería algo diferente:

- distinguir tres estados concretos;
- controlar mejor las entradas desconocidas;
- reducir la influencia del entorno;
- reconocer de forma consistente las muestras utilizadas durante la demostración;
- poder rechazar una captura en lugar de asignar siempre una categoría.

Esto llevó a replantear el problema.

En lugar de intentar construir un clasificador genérico, la implementación final utiliza:

**Vision Feature Prints + comparación por similitud + 5-NN + threshold de rechazo.**

Una de las principales conclusiones técnicas del proceso fue:

> **No siempre entrenar un modelo es la mejor solución. La herramienta debe elegirse a partir del problema real que necesitamos resolver.**

El código histórico de la aproximación inicial no forma parte del repositorio público actual.

---

## Pruebas automatizadas

El proyecto incluye actualmente **22 tests** que cubren, entre otros:

- decisión del matcher;
- votación 5-NN;
- comportamiento alrededor del threshold;
- mapping LOW / MODERATE / HIGH;
- región de análisis;
- preprocesamiento;
- reset del scanner;
- retry después de rechazo;
- reconocimiento mediante referencias.

Tres tests end-to-end relacionados con Vision pueden realizar `skip` en Simulator debido a limitaciones del contexto de inferencia.

Para validar completamente el reconocimiento se recomienda utilizar un iPhone físico.

---

## Ejecutar el proyecto

La forma más sencilla:

1. Clonar el repositorio.
2. Abrir `Aerthys.xcodeproj`.
3. Seleccionar un iPhone o Simulator.
4. Compilar y ejecutar.

Para experimentar con la cámara y el reconocimiento real se recomienda utilizar un iPhone físico.

---

## XcodeGen

El repositorio también incluye:

```text
project.yml
```

por lo que el proyecto Xcode puede regenerarse mediante XcodeGen:

```bash
brew install xcodegen
xcodegen generate
```

Después:

```bash
open Aerthys.xcodeproj
```

XcodeGen es opcional. El `.xcodeproj` está incluido para que el proyecto pueda abrirse directamente en Xcode.

---

## Utilizar tus propias referencias

La arquitectura puede utilizarse como punto de partida para experimentar con otros problemas de reconocimiento visual controlado.

El proceso general sería:

1. definir claramente las categorías;
2. recopilar referencias representativas;
3. estandarizar las condiciones de captura;
4. preparar las imágenes;
5. analizar la separación entre clases;
6. incluir imágenes negativas o desconocidas;
7. calibrar un threshold de rechazo;
8. actualizar el bundle de referencias;
9. validar repetidamente en un dispositivo físico.

El proyecto incluye:

```text
tools/PrepareReferences.swift
tools/CalibrateMatcher.swift
```

como herramientas de apoyo.

Cambiar simplemente las imágenes no garantiza que el sistema funcione correctamente.

**Cada nuevo conjunto de referencias requiere una nueva calibración.**

---

## Limitaciones

Aerthys está construido deliberadamente alrededor de un problema controlado.

Por ello:

- reconoce tres grupos concretos de referencias;
- depende de condiciones de captura relativamente consistentes;
- el fondo blanco mate forma parte del protocolo;
- no identifica cualquier especie de líquen;
- no determina qué contaminante existe en una muestra;
- no mide concentración de contaminantes;
- no detecta metales pesados;
- no mide directamente la calidad del aire;
- no reemplaza análisis de laboratorio;
- no reemplaza estaciones ambientales certificadas.

Aerthys debe entenderse como una **demostración tecnológica de reconocimiento visual**, no como un instrumento científico de medición.

---

## Qué puede aprender un desarrollador de este proyecto

Aerthys es un proyecto pequeño comparado con una aplicación comercial, pero concentra varios problemas reales de desarrollo iOS:

- integración de cámara con AVFoundation;
- SwiftUI y gestión de estados;
- MVVM ligero;
- procesamiento de imágenes;
- regiones de interés;
- Apple Vision;
- Feature Prints;
- métricas de similitud visual;
- k-nearest neighbors;
- rechazo de entradas desconocidas;
- calibración de thresholds;
- caching;
- concurrencia;
- testing;
- XcodeGen;
- diseño de software alrededor de condiciones reales de uso.

También muestra una habilidad especialmente importante en ingeniería:

> **Cambiar de solución cuando las pruebas demuestran que la primera aproximación no resuelve correctamente el problema.**

---

## Qué busca demostrar este proyecto

Desde el punto de vista técnico, Aerthys busca demostrar:

- cómo utilizar Apple Vision para reconocimiento visual basado en referencias;
- cómo diseñar un sistema capaz de decir "no lo sé" en lugar de forzar una clasificación;
- cómo construir un pipeline de cámara y procesamiento completamente on-device;
- cómo calibrar una solución utilizando referencias positivas y ejemplos negativos;
- cómo estructurar y probar una pequeña aplicación SwiftUI enfocada en computer vision;
- cómo adaptar una solución tecnológica a las restricciones de un problema real.

---

## Proceso de desarrollo

Aerthys nació como apoyo a un proyecto estudiantil y terminó convirtiéndose también en una experiencia práctica de desarrollo iOS.

El proceso incluyó:

- comprender qué necesitaban realmente las estudiantes;
- convertir esa necesidad en un problema técnico concreto;
- construir una primera aproximación;
- probarla con muestras físicas;
- detectar comportamientos incorrectos;
- analizar por qué ocurrían;
- cambiar la estrategia de reconocimiento;
- controlar variables como el fondo;
- recopilar nuevas referencias;
- calibrar aceptación y rechazo;
- repetir pruebas en dispositivo físico;
- auditar posteriormente el proyecto;
- eliminar código histórico y material de desarrollo;
- convertir la aplicación en un ejemplo técnico reutilizable y publicable.

Claude Code fue utilizado como acelerador durante partes de la implementación, auditoría, refactorización y documentación.

Las decisiones sobre comportamiento, estrategia técnica, protocolo de pruebas, calibración y cambios realizados a partir de los resultados fueron dirigidas y revisadas durante el desarrollo.

Esta experiencia reforzó una idea importante:

> **Utilizar herramientas de IA no sustituye el criterio técnico. Su valor aparece cuando podemos dirigirlas, validar lo que producen, detectar cuándo una solución no funciona y tomar mejores decisiones a partir de evidencia real.**

---

## Origen: EUREKA 2026

Aerthys fue desarrollado originalmente como apoyo tecnológico para un proyecto presentado por estudiantes de **4.º de secundaria de la I.E. Santa Rosa 6094, Chorrillos**, dentro del concurso escolar de ciencia y tecnología **EUREKA 2026**.

El proyecto relaciona tecnología móvil con el estudio de los líquenes como bioindicadores naturales.

El contexto escolar explica varias de las decisiones del desarrollo:

- debía ser fácil de demostrar;
- debía funcionar offline;
- debía ejecutarse en un dispositivo disponible;
- debía entregar resultados comprensibles;
- debía permitir repetir el análisis durante una exposición;
- debía responder correctamente cuando la cámara no observaba una de las muestras conocidas.

---

> ### 🌱 Nota — septiembre de 2026
>
> Al momento de preparar la publicación de este proyecto, las estudiantes continúan avanzando en las etapas eliminatorias de **EUREKA 2026**.
>
> Más allá del resultado final del concurso, el proceso ya permitió transformar una pregunta escolar en una experiencia real de investigación, experimentación y desarrollo tecnológico.
>
> Esperamos que Aerthys pueda acompañarlas hasta las últimas etapas de la competencia. 🍀

---

## Documentación

Información técnica adicional:

- [`Implementation Notes`](docs/implementation-notes.md)
- [`Calibration Details`](docs/calibration.md)

---

## Licencia

Aerthys se distribuye bajo licencia MIT.

Consulta [`LICENSE`](LICENSE).

---

## Autor

**Stephano Portella — 2026**

