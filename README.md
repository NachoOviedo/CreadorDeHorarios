# CreadorDeHorarios

Proyecto semestral de Paradigmas de Programación (CE1106). Integrantes: Bolaños Porras Byron Josué, López Brenes Esteban Mauricio y Oviedo Murillo Ignacio.

Es un sistema de cuatro etapas, **CEmestre**, que ayuda a un estudiante a construir un horario de matrícula válido. Cada etapa se implementa en un paradigma distinto, es un programa independiente y consume el archivo que produjo la etapa anterior:

| Etapa | Lenguaje | Función | Estado |
|---|---|---|---|
| 1 | C (imperativo) | Construye el catálogo de cursos y calcula choques de horario y elegibilidad de matrícula | Entregada |
| **2** | **Racket (funcional)** | **Genera y filtra combinaciones posibles de horario** | **Esta entrega** |
| 3 | Prolog | Aplica reglas de restricción (créditos máximos, compatibilidades) | Pendiente |
| 4 | Java | Integra el resultado final y lo presenta al usuario | Pendiente |

Este README tiene dos partes: la **Etapa 2** (Racket) y, a continuación, la **Etapa 1** (C), que produce los datos que la Etapa 2 consume.

---

# Etapa 2: Racket (paradigma funcional)

Esta etapa toma el catálogo que exporta el módulo de C (`Output/catalogoExp.json`) y las preferencias del estudiante, y genera todas las combinaciones de horario **sin choques** cuyos créditos estén dentro del rango que el estudiante pidió. El resultado es un archivo JSON (`Output/combinaciones.json`) que va a leer la etapa de Prolog.

El módulo **no** arma un horario final, no sugiere ninguna combinación ni aplica reglas más allá de los créditos: eso queda para las etapas siguientes.

## Arquitectura del proyecto (Etapa 2)

```
main.rkt
  │
  ├─► generador.rkt      → lee Output/catalogoExp.json y lo convierte a structs
  ├─► preferencias.rkt   → lee y valida las preferencias del estudiante
  ├─► combinaciones.rkt  → stream de combinaciones sin choques (poda temprana)
  ├─► filtros.rkt        → filtro polimórfico, usado para el rango de créditos
  └─► exportador.rkt     → escribe las combinaciones en JSON, una por una

tipos.rkt     → todas las structs con tipos explícitos (Typed Racket)
jsonUtil.rkt  → lectura de JSON con validación de tipos, compartida
tests/pruebas.rkt → pruebas con rackunit
```

**Flujo de ejecución** (`ejecutar` en `main.rkt`):

1. `cargar-catalogo` lee `Output/catalogoExp.json` y arma un `Catalogo`.
2. `cargarPreferencias` y `validarPreferencias` leen el archivo de preferencias y comprueban que los cursos y grupos existan y que el rango de créditos sea válido.
3. `armar-opciones` convierte cada curso de interés en una lista de `Seleccion` (un curso con uno de sus grupos). Solo entran los cursos con `puedeMatricular = 1`, y solo los grupos que el estudiante aceptó (si no indicó ninguno, entran todos).
4. `subconjuntos` produce, como stream, cada subconjunto de esos cursos.
5. `combinaciones-sin-choques` genera, para cada subconjunto, las combinaciones de un grupo por curso, descartando un grupo apenas choca con uno ya elegido.
6. `armar-combinacion` suma los créditos de cada combinación.
7. `filtrar-rango-creditos` conserva solo las combinaciones dentro del rango de créditos.
8. `exportar-combinaciones` escribe cada combinación al archivo apenas el stream la produce.

## Cómo compilar, ejecutar y probar

El programa de C genera el catálogo y el de Racket lo consume:

```bash
# 1. Generar el catálogo (Etapa 1)
./build/CreadorDeHorarios Estudiantes/historial_estudiante1.json

# 2. Generar las combinaciones (Etapa 2)
racket main.rkt
# o indicando cada archivo:
racket main.rkt Output/catalogoExp.json Estudiantes/Preferencias/PreferenciasEstudiante1.json Output/combinaciones.json

# 3. Pruebas
raco test tests/pruebas.rkt
```

Sin argumentos, `main.rkt` usa el catálogo y las preferencias del estudiante 1. Hay un ejemplo de preferencias para cada estudiante en `Estudiantes/Preferencias/`.

## Decisiones de diseño

### Justificación de decisiones propias

1. **Se generan subconjuntos de los cursos de interés, no solo la lista completa.** Si el programa exigiera un grupo por *cada* curso de la lista, todas las combinaciones sumarían los mismos créditos y el filtro por rango no descartaría nada. Al tratar la lista como un conjunto de cursos posibles, el rango de créditos es lo que decide qué horarios sirven. `subconjuntos` es perezosa: producir el primer subconjunto de una lista de 40 cursos no recorre los 2^40.
2. **Racket no recalcula requisitos ni choques.** Usa el campo `puedeMatricular` (solo el valor `1`) y la lista `choques` que ya calculó C. Esto sigue la división de responsabilidades de las etapas y evita tener dos implementaciones de la misma regla que se puedan contradecir.
3. **Poda temprana de choques.** En `combinaciones.rkt`, `probar-opciones` revisa si cada grupo choca con los ya elegidos *antes* de seguir con los cursos restantes, así que una rama con choque nunca se completa.
4. **Inmutabilidad.** No se usa `set!`, estructuras mutables ni variables globales reasignadas. El estado se lleva con parámetros de recursión: la lista `elegidos` al generar y el contador `cantidad` al exportar.
5. **Una función polimórfica reutilizada.** `filtrar` y `filtrar-rango-creditos` tienen tipo `(All (A) ...)` y reciben la función que obtiene los créditos. En `main.rkt` se usan con `Combinacion`; en las pruebas, también con enteros y con strings. `subconjuntos` también es polimórfica.
6. **Tipos explícitos en todo el código** (`#lang typed/racket`). Además, `jsonUtil.rkt` valida el tipo de cada campo del JSON antes de usarlo y falla con un mensaje claro si falta o es de otro tipo.

### Caso límite real que encontramos

El primer archivo de preferencias de ejemplo pedía CE1101 y CE1104, pero el estudiante 1 ya los tenía aprobados (`puedeMatricular = 2`), y además sumaban 6 créditos con un mínimo de 12. El resultado era un archivo vacío sin ninguna explicación.

Se resolvió así: `cursos-omitidos` detecta los cursos de interés que no se pueden matricular, `ejecutar` avisa por `stderr` cuáles se ignoraron, y la generación sigue con los demás. Si ninguna combinación cumple el rango, el archivo igual se escribe como JSON válido con `"combinaciones": []`, para que la etapa siguiente no falle. El ejemplo `PreferenciasEstudiante1.json` incluye CE1101 a propósito para mostrar este aviso.

### Justificación del formato de salida

El formato es **JSON**, y se escribe **combinación por combinación**. Esta segunda decisión viene de usar streams: como las combinaciones se producen una a una, el exportador las escribe apenas aparecen y nunca guarda la lista completa en memoria. Con JSON eso se logra escribiendo `[`, cada objeto separado por coma y `]`. Además, JSON ya se usa en todo el proyecto (el catálogo de C, el historial, las preferencias), y Prolog puede leerlo con `library(http/json)`.

```json
{
  "creditosMin": 8,
  "creditosMax": 14,
  "combinaciones": [
    {
      "creditosTotales": 9,
      "cursos": [
        { "curso": "CE2103", "grupo": 1, "carrera": "Ing.Computadores", "creditos": 4 },
        { "curso": "QU1106", "grupo": 1, "carrera": "Ing.Computadores", "creditos": 3 }
      ]
    }
  ]
}
```

Los campos que pide el enunciado son: los pares curso-grupo (`curso` y `grupo`), los créditos totales (`creditosTotales`) y la carrera de cada curso (`carrera`). Se agregaron dos cosas, justificadas por quien consume el archivo:

- `creditos` en cada curso: Prolog puede aplicar reglas de créditos por curso sin volver a cargar el catálogo.
- `creditosMin` y `creditosMax` al inicio: dejan registrado con qué rango se generó el archivo.

## Estructuras de datos desarrolladas (Etapa 2)

Definidas en `tipos.rkt`. Todas son `struct` inmutables y transparentes:

- **`Bloque`**, **`Grupo`**, **`Curso`**, **`ParChoque`** y **`Catalogo`**: reflejan el JSON que exporta C (ver la sección de la Etapa 1).
- **`Interes`** — un curso que le interesa al estudiante y los grupos que acepta. Si la lista de grupos está vacía, acepta cualquiera.
- **`Preferencias`** — la lista de `Interes` y los créditos mínimos y máximos.
- **`Seleccion`** — un `Curso` junto con el `Grupo` elegido.
- **`Combinacion`** — una lista de `Seleccion` (una por curso) y sus créditos totales.
- **Streams** (`Streamof`) — las combinaciones nunca se guardan como lista completa: se generan, filtran y escriben de una en una.

## Uso de streams

La generación completa es un pipeline de streams: `subconjuntos` → `combinaciones-por-subconjunto` → `stream-map armar-combinacion` → `filtrar-rango-creditos` → `escribir-combinaciones`. Ninguna etapa construye la lista completa de combinaciones; el único consumidor que recorre todo el stream es el exportador, que escribe cada elemento y lo suelta.

## Pruebas

`tests/pruebas.rkt` usa un catálogo pequeño armado a mano (con un choque conocido y un curso no matriculable), así que no depende de ningún archivo. Prueban: los subconjuntos, la omisión de cursos no habilitados, que no haya combinaciones con choques, el filtro por créditos con distintos tipos de dato, y el JSON exportado (incluido el caso sin combinaciones).

## Limitaciones conocidas (Etapa 2)

- Si el estudiante deja `"grupos": []` en varios cursos con muchos grupos (por ejemplo MA0101 tiene 11 y QU1102 tiene 13), el número de combinaciones crece rápido. Se escriben igual, pero el archivo puede ser grande; conviene listar solo los grupos que realmente le sirven.
- `hay-choque?` busca cada par en la lista completa de choques. Es suficiente para los catálogos actuales, pero un índice por par sería más rápido con catálogos más grandes.

---

# Etapa 1: C (paradigma imperativo)

Esta etapa carga el historial del estudiante, elige el catálogo de cursos que le corresponde según su carrera, modela ese catálogo, detecta qué grupos son incompatibles entre sí, determina qué cursos puede matricular el estudiante según su historial, y exporta todo a un archivo que la etapa de Racket lee.

## Arquitectura del proyecto (Etapa 1)

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
- **`Curso`** — código, nombre, carrera (se toma del historial del estudiante, por eso los JSON del catálogo no la repiten), créditos, arreglos de nombres de requisitos y correquisitos, su arreglo de `Grupo`, y `puedeMatricular` (el resultado de la evaluación de elegibilidad).
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

`Output/catalogoExp.json` contiene, por cada curso: código, nombre, carrera, créditos, `puedeMatricular`, requisitos, correquisitos, y su arreglo de grupos (cada uno con número, profesor, si choca, y sus bloques de horario). Además incluye un arreglo `"choques"` con la lista completa de pares de grupos detectados como incompatibles (sujeta al límite `MAX_CHOQUES` descrito arriba).

## Datos de entrada

Los datos de ambas carreras (Computadores en `Horarios/compu.json`, Mantenimiento Industrial en `Horarios/mante.json`) fueron recolectados de la Guía de Horarios institucional del TEC, cubriendo del semestre 0 al 6 de cada plan de estudios, con los horarios de Cartago del primer semestre de 2026. Los historiales de estudiantes se esperan como archivos JSON individuales (por ejemplo en una carpeta `Estudiantes/`), cada uno con carnet, nombre, carrera y la lista de códigos de cursos ya aprobados.

## Limitaciones y pendientes conocidos

- La comparación de carrera es sensible a mayúsculas y tildes (`strcmp` exacto): cualquier variación de formato en el historial provoca que no se encuentre catálogo, sin sugerencia de a qué carrera se refería.
- `MAX_CHOQUES = 10000`: el catálogo de Mantenimiento ya genera 8 966 pares, así que agregar más cursos o grupos puede llegar al límite y truncar la lista de pares sin avisar.
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