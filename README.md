# CreadorDeHorarios

Proyecto semestral de Paradigmas de Programación (CE1106) — **Etapa 1: Paradigma Imperativo (C)**.

Este módulo es la primera de cuatro etapas del sistema **CEmestre**, que ayuda a un estudiante a construir un horario de matrícula válido. Cada etapa se implementa en un paradigma distinto y consume el archivo que produjo la etapa anterior:

| Etapa | Lenguaje | Función |
|---|---|---|
| **1 (esta)** | C | Construye el catálogo de cursos y calcula choques de horario y elegibilidad de matrícula |
| 2 | Racket | Genera y filtra combinaciones posibles de horario |
| 3 | Prolog | Aplica reglas de restricción (créditos máximos, compatibilidades) |
| 4 | Java | Integra el resultado final y lo presenta al usuario |

Esta etapa carga el historial del estudiante, elige el catálogo de cursos que le corresponde según su carrera, modela ese catálogo, detecta qué grupos son incompatibles entre sí, determina qué cursos puede matricular el estudiante según su historial, y exporta todo a un archivo que la etapa de Racket va a leer.

## Arquitectura del proyecto

El programa está dividido en módulos independientes, cada uno con una responsabilidad concreta:

```
main (mainDePrueba.c)
  │
  ├─► parser.c/.h           → carga desde JSON el historial del estudiante y el catálogo de cursos
  │
  ├─► comprobarChoques.c/.h → detecta choques de horario entre grupos del catálogo cargado
  │
  ├─► procesador.c/.h       → evalúa si el estudiante puede matricular cada curso del catálogo
  │
  └─► exportador.c/.h       → escribe el catálogo procesado a un archivo JSON de salida
```

`mainDePrueba.c` además contiene la tabla `CATALOGOS_POR_CARRERA`, que decide qué archivo de catálogo cargar según la carrera del estudiante (ver sección siguiente).

**Flujo de ejecución** (en `main`):

1. `cargarHistorialEstudiante()` carga primero el historial del estudiante, porque de ahí se obtiene el campo `carrera`, y la carrera es la que decide qué catálogo corresponde cargar.
2. Se determina la ruta del catálogo: si se dio un segundo argumento en la línea de comandos, se usa esa ruta directamente; si no, se busca en `CATALOGOS_POR_CARRERA` la ruta asociada a `estudiante.carrera`. Si la carrera no está registrada en la tabla, el programa termina con error.
3. `cargarCatalogo()` lee ese archivo de cursos (JSON) y llena la struct `Catalogo`.
4. `detectarChoques()` recorre todos los pares de grupos del catálogo y marca cuáles chocan.
5. `evaluarElegibilidadCatalogo()` calcula, para cada curso, si el estudiante lo puede matricular.
6. Se imprime en consola un resumen del catálogo procesado y del historial (`imprimirCatalogo()`, `imprimirEstudiante()`), como apoyo para depuración.
7. `exportarCatalogo()` escribe el catálogo completo (con choques y elegibilidad ya calculados) a `Output/catalogoExp.json`.

Cada paso depende únicamente del resultado del anterior — ningún módulo vuelve a leer o reinterpretar el JSON original una vez que los datos están en las structs de C.

**Constantes:** todos los tamaños máximos (`MAX_CURSOS`, `MAX_GRUPOS_POR_CURSO`, `MAX_LEN_NOMBRE`, etc.) y los códigos de error (`OK`, `ERROR_ARCHIVO_NO_EXISTE`, etc.) viven en un único archivo separado, `constantes.h`.

**Librería externa:** se usa [cJSON](https://github.com/DaveGamble/cJSON) para leer y escribir JSON, incluida en `src/cJSON.c` y `src/cJSON.h`.

## Selección del catálogo según la carrera del estudiante

El historial de un estudiante no dice directamente qué catálogo de cursos usar; solo trae un campo `"carrera"` en texto libre. `mainDePrueba.c` resuelve esto con una tabla estática:

```c
static const CarreraCatalogo CATALOGOS_POR_CARRERA[] = {
    { "Ing.Computadores",  "Horarios/compu.json" },
    { "Ing.Mantenimiento", "Horarios/mante.json" },
};
```

La búsqueda compara `estudiante.carrera` contra cada entrada con `strcmp`, así que el valor debe coincidir **exactamente** (mayúsculas y tildes incluidas) con lo que traiga el JSON del historial. Si no hay coincidencia, `rutaCatalogoParaCarrera()` devuelve `NULL` y el programa termina indicando que no hay catálogo configurado para esa carrera.

`CANTIDAD_CARRERAS` (en `constantes.h`) debe mantenerse igual a la cantidad de filas de esta tabla, ya que se usa como límite del ciclo de búsqueda; agregar una carrera nueva implica actualizar ambos lugares.

Este mecanismo automático se puede omitir pasando la ruta del catálogo explícitamente como segundo argumento en la línea de comandos (ver "Cómo compilar y ejecutar").

## Estructuras de datos desarrolladas

Definidas en `structCatalogoCursos.h` y `structEstudiante.h`:

- **`Bloque`** — un tramo de horario: día, hora de inicio y hora de fin. Un grupo puede tener varios bloques (por ejemplo, un curso que se reúne martes y jueves).
- **`Grupo`** — número de grupo, profesor, su arreglo de `Bloque`, y un booleano `choca` que resume si tiene algún conflicto de horario con otro grupo del catálogo.
- **`Curso`** — código, nombre, créditos, arreglos de nombres de requisitos y correquisitos, su arreglo de `Grupo`, y `puedeMatricular` (el resultado de la evaluación de elegibilidad).
- **`ParChoque`** — identifica un par específico de grupos que chocan entre sí (código de curso y número de grupo de cada lado).
- **`Catalogo`** — el arreglo completo de `Curso`, más el arreglo de `ParChoque` detectados y su cantidad.
- **`Estudiante`** — carnet, nombre, carrera (usada para elegir el catálogo), y el arreglo de códigos de los cursos que ya aprobó.

Todas las structs usan arreglos de tamaño fijo (no memoria dinámica para las listas), con sus límites definidos en `constantes.h`. Esta decisión evita la complejidad de manejo manual de memoria dinámica para estructuras que tienen un tamaño acotado y conocido de antemano.

## Decisiones de diseño

### 1. Detección de choques: booleano + lista explícita de pares

El enunciado pide, como mínimo, que cada curso indique si choca con al menos otro curso/grupo del catálogo — un booleano. Decidimos ir más allá y también exportar la **lista completa de pares que chocan** (`ParChoque`), no solo el booleano por grupo.

La razón es que la etapa de Racket necesita responder preguntas como "¿el grupo 2 de CE1103 es compatible con el grupo 1 de CE1106?" — una pregunta entre pares específicos. Con solo el booleano, Racket sabría que un grupo choca con *algo*, pero no con *qué*, y tendría que recalcular todo el choque de horarios por su cuenta. Con la lista de pares, la siguiente etapa solo consulta y filtra.

`detectarChoques()` recorre cada par de grupos del catálogo exactamente una vez (evitando comparar un grupo consigo mismo y evitando pares duplicados), incluyendo pares de grupos que pertenecen al mismo curso (por ejemplo, el grupo 1 y el grupo 2 de un curso con varias secciones).

### 2. Requisitos y correquisitos: resolución de nombre a código

Los archivos de entrada (`compu.json`, `mante.json`) listan los requisitos y correquisitos de un curso por nombre completo (ej. `"Introducción a la Programación"`), mientras que el historial del estudiante y los códigos de curso del catálogo están en código (ej. `"CE1101"`).

La solución fue agregar `buscarCodigoPorNombre()` en `procesador.c`, que resuelve el nombre de un requisito a su código buscándolo en el catálogo, antes de comparar contra los cursos aprobados del estudiante. Esto se aplica tanto en `verificarRequisitosCumplidos()` como en `verificarCorrequisitos()`.

### 3. Requisito no encontrado en el catálogo

Como esta etapa solo carga los primeros semestres de cada carrera (el catálogo que le corresponde según su carrera), es posible que un curso tenga como requisito una materia que no está en ese catálogo. Se decidió que, en ese caso, el requisito se trata como **no cumplido**: el sistema no asume que el estudiante cumple algo que no puede verificar contra los datos disponibles. Esto se refleja en el código como `codigoRequisito == NULL` dentro de `verificarRequisitosCumplidos()`.

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

El día más largo en español usado en los datos es "miércoles" — 9 letras, pero con tilde codificada en UTF-8 la "é" ocupa 2 bytes, dando 10 bytes + el terminador `\0` = 11. Se dejó en 12 para tener 1 byte de margen, ajustado al dato real (los archivos de catálogo usan los nombres completos en minúscula: `"martes"`, `"miércoles"`, `"jueves"`, `"viernes"`) en vez de un número arbitrario.

### 6. Formato de salida: JSON

Se eligió JSON para el archivo de salida porque:
- Ya se usaba `cJSON` para leer los archivos de entrada, así que no se agregó ninguna dependencia nueva para escribir.
- Es un formato jerárquico natural para representar cursos que contienen grupos que contienen bloques.
- Racket tiene soporte directo para parsear JSON, facilitando la siguiente etapa.

## Caso límite considerado

Los catálogos de las dos carreras soportadas (Ingeniería en Computadores en `compu.json`, Ingeniería en Mantenimiento Industrial en `mante.json`) **no se combinan**: cada ejecución carga un único catálogo, el que corresponde a la carrera del estudiante. Sin embargo, ambos archivos repiten, con el mismo código, varios cursos de servicio compartidos entre ambos planes de estudio (por ejemplo `FI1101`, `FI1102`, `FI1201`, `FI1202`, `MA0101`, `MA1102`, `MA1103`, `MA2104`, `PI2609`, `QU1102`, `QU1106`, `CS1502`, `SE1100`, `SE1200`, `SE1400`), cada uno de forma independiente dentro de su propio archivo.

El caso límite real que el módulo de detección de choques sí debe manejar ocurre **dentro de un mismo catálogo**: varios cursos tienen muchos grupos (hasta `MAX_GRUPOS_POR_CURSO`), y hace falta comparar todos los pares de grupos posibles —incluyendo grupos distintos de un mismo curso— sin comparar un grupo consigo mismo ni repetir un par dos veces. `detectarChoques()` está diseñado para cubrir exactamente eso, sin importar cuántos grupos tenga cada curso.

**Límite adicional:** la lista explícita de pares (`catalogo->choques`) tiene capacidad fija (`MAX_CHOQUES = 10000`). El booleano `choca` de cada grupo siempre se marca correctamente aunque se llegue a este límite, pero si se supera, los pares adicionales dejan de agregarse a la lista exportada.

## Archivo de salida

`Output/catalogoExp.json` contiene, por cada curso: código, nombre, créditos, `puedeMatricular`, requisitos, correquisitos, y su arreglo de grupos (cada uno con número, profesor, si choca, y sus bloques de horario). Además incluye un arreglo `"choques"` con la lista completa de pares de grupos detectados como incompatibles (sujeta al límite `MAX_CHOQUES` descrito arriba).

## Datos de entrada

Los datos de ambas carreras (Computadores en `Horarios/compu.json`, Mantenimiento Industrial en `Horarios/mante.json`) fueron recolectados de la Guía de Horarios institucional del TEC, cubriendo los primeros semestres de cada plan de estudios. Los historiales de estudiantes se esperan como archivos JSON individuales (por ejemplo en una carpeta `Estudiantes/`), cada uno con carnet, nombre, carrera y la lista de códigos de cursos ya aprobados.

## Limitaciones y pendientes conocidos

- El valor exacto del campo `"carrera"` para Ingeniería en Mantenimiento (`"Ing.Mantenimiento"` en `CATALOGOS_POR_CARRERA`) todavía no está confirmado contra un historial real; hay un `TODO` explícito en `mainDePrueba.c` sobre esto. Si el historial trae un valor distinto, la carga del catálogo falla.
- La comparación de carrera es sensible a mayúsculas y tildes (`strcmp` exacto): cualquier variación de formato en el historial provoca que no se encuentre catálogo, sin sugerencia de a qué carrera se refería.
- `MAX_LEN_RUTA` está definido en `constantes.h` pero no se usa actualmente en el código.
- En `comprobarChoques.h` el guard de inclusión tiene una inconsistencia de nombre (`#define ... _COMPROVARCHOQUES_H` vs. el comentario del `#endif`, que dice `_COMPROBARCHOQUES_H`); no afecta la compilación, pero convendría unificarlo.

## Licencia

Este proyecto se distribuye bajo la **Apache License 2.0** (ver `LICENSE`). La librería de terceros `cJSON` incluida en `src/` mantiene su propia licencia MIT (ver el encabezado de `cJSON.c`/`cJSON.h`).

## Cómo compilar y ejecutar

```bash
mkdir -p build
cd build
cmake ..
cmake --build .
cd ..
./build/CreadorDeHorarios [ruta_historial] [ruta_catalogo]
```

- `ruta_historial` (opcional): por defecto `Estudiantes/historial_estudiante1.json`.
- `ruta_catalogo` (opcional, segundo argumento): si se omite, se elige automáticamente según la carrera indicada en el historial (ver "Selección del catálogo según la carrera del estudiante"); si se da, fuerza ese catálogo específico, útil para pruebas.

El resultado se escribe en `Output/catalogoExp.json`.
