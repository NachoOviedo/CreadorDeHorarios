# CreadorDeHorarios

Proyecto semestral de Paradigmas de Programación (CE1106) — **Etapa 1: Paradigma Imperativo (C)**.

Este módulo es la primera de cuatro etapas del sistema **CEmestre**, que ayuda a un estudiante a construir un horario de matrícula válido. Cada etapa se implementa en un paradigma distinto y consume el archivo que produjo la etapa anterior:

| Etapa | Lenguaje | Función |
|---|---|---|
| **1 (esta)** | C | Construye el catálogo de cursos y calcula choques de horario y elegibilidad de matrícula |
| 2 | Racket | Genera y filtra combinaciones posibles de horario |
| 3 | Prolog | Aplica reglas de restricción (créditos máximos, compatibilidades) |
| 4 | Java | Integra el resultado final y lo presenta al usuario |

Esta etapa modela el catálogo, detecta qué grupos son incompatibles entre sí, determina qué cursos puede matricular el estudiante según su historial, y exporta todo a un archivo que la etapa de Racket va a leer.

## Arquitectura del proyecto

El programa está dividido en módulos independientes, cada uno con una responsabilidad concreta:

```
main (mainDePrueba.c)
  │
  ├─► parser.c/.h          → carga el catálogo y el historial del estudiante desde JSON
  │
  ├─► comprobarChoques.c/.h → detecta choques de horario entre grupos
  │
  ├─► procesador.c/.h       → evalúa si el estudiante puede matricular cada curso
  │
  └─► exportador.c/.h       → escribe el catálogo procesado a un archivo JSON de salida
```

**Flujo de ejecución** (en `main`):

1. `cargarCatalogo()` lee el archivo de cursos (JSON) y llena la struct `Catalogo`.
2. `detectarChoques()` recorre todos los pares de grupos del catálogo y marca cuáles chocan.
3. `cargarHistorialEstudiante()` lee el historial de cursos aprobados del estudiante.
4. `evaluarElegibilidadCatalogo()` calcula, para cada curso, si el estudiante lo puede matricular.
5. `exportarCatalogo()` escribe el catálogo completo (con choques y elegibilidad ya calculados) a `Output/catalogoExp.json`.

Cada paso depende únicamente del resultado del anterior — ningún módulo vuelve a leer o reinterpretar el JSON original una vez que los datos están en las structs de C.

**Constantes:** todos los tamaños máximos (`MAX_CURSOS`, `MAX_GRUPOS_POR_CURSO`, `MAX_LEN_NOMBRE`, etc.) y los códigos de error (`OK`, `ERROR_ARCHIVO_NO_EXISTE`, etc.) viven en un único archivo separado, `constantes.h`.

**Librería externa:** se usa [cJSON](https://github.com/DaveGamble/cJSON) para leer y escribir JSON, incluida en `src/cJSON.c` y `src/cJSON.h`.

## Estructuras de datos desarrolladas

Definidas en `structCatalogoCursos.h` y `structEstudiante.h`:

- **`Bloque`** — un tramo de horario: día, hora de inicio y hora de fin. Un grupo puede tener varios bloques (por ejemplo, un curso que se reúne martes y jueves).
- **`Grupo`** — número de grupo, profesor, su arreglo de `Bloque`, y un booleano `choca` que resume si tiene algún conflicto de horario con otro grupo del catálogo.
- **`Curso`** — código, nombre, créditos, arreglos de nombres de requisitos y correquisitos, su arreglo de `Grupo`, y `puedeMatricular` (el resultado de la evaluación de elegibilidad).
- **`ParChoque`** — identifica un par específico de grupos que chocan entre sí (código de curso y número de grupo de cada lado).
- **`Catalogo`** — el arreglo completo de `Curso`, más el arreglo de `ParChoque` detectados y su cantidad.
- **`Estudiante`** — carnet, nombre, y el arreglo de códigos de los cursos que ya aprobó.

Todas las structs usan arreglos de tamaño fijo (no memoria dinámica para las listas), con sus límites definidos en `constantes.h`. Esta decisión evita la complejidad de manejo manual de memoria dinámica para estructuras que tienen un tamaño acotado y conocido de antemano.

## Decisiones de diseño

### 1. Detección de choques: booleano + lista explícita de pares

El enunciado pide, como mínimo, que cada curso indique si choca con al menos otro curso/grupo del catálogo — un booleano. Decidimos ir más allá y también exportar la **lista completa de pares que chocan** (`ParChoque`), no solo el booleano por grupo.

La razón es que la etapa de Racket necesita responder preguntas como "¿el grupo 2 de CE1103 es compatible con el grupo 1 de CE1106?" — una pregunta entre pares específicos. Con solo el booleano, Racket sabría que un grupo choca con *algo*, pero no con *qué*, y tendría que recalcular todo el choque de horarios por su cuenta. Con la lista de pares, la siguiente etapa solo consulta y filtra.

`detectarChoques()` recorre cada par de grupos exactamente una vez (evitando comparar un grupo consigo mismo y evitando pares duplicados), incluyendo pares dentro de un mismo curso.

### 2. Requisitos y correquisitos: resolución de nombre a código

Los archivos de entrada (`compu.json`, `mante.json`) listan los requisitos y correquisitos de un curso por nombre completo (ej. `"Introducción a la Programación"`), mientras que el historial del estudiante y los códigos de curso del catálogo están en código (ej. `"CE1101"`).

La solución fue agregar `buscarCodigoPorNombre()` en `procesador.c`, que resuelve el nombre de un requisito a su código buscándolo en el catálogo, antes de comparar contra los cursos aprobados del estudiante. Esto se aplica tanto en `verificarRequisitosCumplidos()` como en `verificarCorrequisitos()`.

### 3. Requisito no encontrado en el catálogo

Como esta etapa solo carga los primeros 4 semestres de cada carrera, es posible que un curso tenga como requisito una materia que no está en el catálogo cargado. Se decidió que, en ese caso, el requisito se trata como **no cumplido**: el sistema no asume que el estudiante cumple algo que no puede verificar contra los datos disponibles. Esto se refleja en el código como `codigoRequisito == NULL` dentro de `verificarRequisitosCumplidos()`.

### 4. `puedeMatricular` como estado de 4 valores

En vez de un booleano simple, `puedeMatricular` usa 4 estados:

| Valor | Significado |
|---|---|
| `0` | No puede matricularlo (requisitos no cumplidos) |
| `1` | Puede matricularlo (requisitos y correquisitos cumplidos) |
| `2` | Ya lo aprobó |
| `3` | Estado intermedio: cumple requisitos, pendiente de verificar correquisitos |

El valor `3` existe porque la verificación de requisitos y de correquisitos se hace en dos pasadas separadas (`verificarRequisitosCumplidos()` primero, `verificarCorrequisitos()` después) — un curso solo puede evaluarse en correquisitos si ya se confirmó que cumple requisitos.

### 5. `MAX_LEN_DIA = 12`

El día más largo en español es "miércoles" — 9 letras, pero con tilde codificada en UTF-8 la "é" ocupa 2 bytes, dando 10 bytes + el terminador `\0` = 11. Se dejó en 12 para tener 1 byte de margen, ajustado al dato real en vez de un número arbitrario.

### 6. Formato de salida: JSON

Se eligió JSON para el archivo de salida porque:
- Ya se usaba `cJSON` para leer los archivos de entrada, así que no se agregó ninguna dependencia nueva para escribir.
- Es un formato jerárquico natural para representar cursos que contienen grupos que contienen bloques.
- Racket tiene soporte directo para parsear JSON, facilitando la siguiente etapa.

## Caso límite considerado

Al combinar los catálogos de dos carreras (Ingeniería en Computadores y Mantenimiento Industrial), varios cursos de servicio son compartidos entre ambos planes de estudio (por ejemplo, las actividades culturales y deportivas). El módulo de detección de choques está diseñado para manejar correctamente cualquier cantidad de grupos por curso, incluyendo comparaciones entre grupos del mismo código de curso, precisamente para cubrir este tipo de solapamiento entre carreras.

## Archivo de salida

`Output/catalogoExp.json` contiene, por cada curso: código, nombre, créditos, `puedeMatricular`, requisitos, correquisitos, y su arreglo de grupos (cada uno con número, profesor, si choca, y sus bloques de horario). Además incluye un arreglo `"choques"` con la lista completa de pares de grupos detectados como incompatibles.

## Datos de entrada

Los datos de ambas carreras (Computadores en `Horarios/compu.json`, Mantenimiento Industrial en `Horarios/mante.json`) fueron recolectados de la Guía de Horarios institucional del TEC, cubriendo los primeros 4 semestres de cada plan de estudios.

## Cómo compilar y ejecutar

```bash
mkdir -p build
cd build
cmake ..
cmake --build .
cd ..
./build/CreadorDeHorarios [ruta_catalogo] [ruta_historial]
```

Por defecto usa `Horarios/compu.json` y `Estudiantes/historial_estudiante.json` si no se pasan argumentos. El resultado se escribe en `Output/catalogoExp.json`.