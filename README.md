# CreadorDeHorarios

Proyecto semestral de Paradigmas de Programación (CE1106). Integrantes: Bolaños Porras Byron Josué, López Brenes Esteban Mauricio y Oviedo Murillo Ignacio.

Es un sistema de cuatro etapas, **CEmestre**, que ayuda a un estudiante a construir un horario de matrícula válido. Cada etapa se implementa en un paradigma distinto, es un programa independiente y consume el archivo que produjo la etapa anterior:

| Etapa | Lenguaje | Función | Estado |
|---|---|---|---|
| 1 | C (imperativo) | Construye el catálogo de cursos y calcula choques de horario y elegibilidad de matrícula | Entregada |
| 2 | Racket (funcional) | Genera y filtra combinaciones posibles de horario | Entregada |
| **3** | **Prolog (lógico)** | **Evalúa cada combinación contra reglas de política (balance entre carreras, límite por área, incompatibilidades) e indica si la cumple o por qué no** | **Esta entrega** |
| 4 | Java | Integra el resultado final y lo presenta al usuario | Pendiente |

Este README tiene tres partes: la **Etapa 3** (Prolog), la **Etapa 2** (Racket) y la **Etapa 1** (C), que produce los datos que consume la Etapa 2. El flujo completo es C → Racket → Prolog.

---

# Etapa 3: Prolog (paradigma lógico)

Esta etapa toma las combinaciones que genera Racket (`Output/combinaciones.json`), evalúa cada una contra tres **reglas de política** (balance entre carreras, límite por área e incompatibilidad) y exporta, por cada combinación, si **cumple** y, si no, **la primera regla que viola** (`Output/resultado.json`). Ese archivo es el que va a leer la etapa de Java.

El módulo **no** genera combinaciones nuevas, **no** vuelve a filtrar por créditos y **no** presenta resultados: solo evalúa y explica.

## Arquitectura del proyecto (Etapa 3)

```
main.pl
  │
  ├─► carga.pl       → lee combinaciones.json y lo convierte en hechos combinacion/3
  ├─► exportador.pl  → recorre todas las combinaciones por backtracking y escribe resultado.json
  │     └─► razon.pl     → veredicto y primera regla violada (corte + orden de reglas)
  │           └─► reglas.pl    → las tres reglas como predicados
  │                 └─► politica.pl → hechos de política (porcentajes, máximos por área, pares)

tests/carga_test.pl   → pruebas de politica.pl y carga.pl
tests/reglas_test.pl  → pruebas de reglas.pl y razon.pl
```

| Archivo | Responsabilidad |
|---|---|
| `politica.pl` | **Solo hechos**: `max_porcentaje_carrera/2`, `max_cursos_area/2`, `par_incompatible/2`, con valores por defecto. Cambiar la política no obliga a tocar ninguna regla. |
| `carga.pl` | Lee el JSON, lo valida completo y recién entonces escribe los hechos (si el archivo es defectuoso no deja una carga a medias). |
| `reglas.pl` | Las tres reglas. Ningún número está escrito en ellas: todo se consulta en `politica.pl`. |
| `razon.pl` | Decide **cuál** regla se reporta primero y la convierte a texto. |
| `exportador.pl` | Recorre `combinacion/3` por backtracking y escribe el JSON de salida. |
| `main.pl` | Punto de entrada por línea de comandos. |

**Flujo de ejecución** (`main` en `main.pl`):

1. `cargar_combinaciones/2` lee `Output/combinaciones.json` y deja un hecho `combinacion/3` por cada combinación.
2. `exportar_resultados/3` recorre esos hechos con `findall/3` (backtracking sobre `combinacion/3`).
3. Para cada combinación calcula `veredicto/2` (cumple o no) y `razon_texto/2` (primera regla violada).
4. Escribe todo en `Output/resultado.json`.

## Cómo ejecutar y probar

El programa de Racket genera las combinaciones y el de Prolog las evalúa:

```bash
# 1. Catálogo (Etapa 1) y combinaciones (Etapa 2), como se explica más abajo
# 2. Evaluar con Prolog (Etapa 3)
swipl -g main -t halt main.pl
# o indicando los archivos:
swipl -g main -t halt main.pl Output/combinaciones.json Output/resultado.json

# 3. Pruebas
swipl -g run_tests -t halt tests/carga_test.pl
swipl -g run_tests -t halt tests/reglas_test.pl
```

Sin argumentos usa `Output/combinaciones.json` como entrada y `Output/resultado.json` como salida. Con un solo argumento, ese es la entrada.

## Extensión del proyecto: campo `area` y 8 semestres

- **Planes a 8 semestres.** Se amplió `Horarios/compu.json` y `Horarios/mante.json` reutilizando el mismo módulo de C: solo se agregaron datos, no se cambió la lógica de choques ni de elegibilidad.
- **Campo `area`.** Se calcula en C (`area.c`, función `obtenerArea`), se guarda en `Curso.area` (`structCatalogoCursos.h`), se exporta en `catalogoExp.json`, se propaga por Racket (`tipos.rkt` y `exportador.rkt`) y llega a Prolog dentro de cada curso de `combinaciones.json`. La lógica de Racket no se modificó: el campo solo viaja.
- **Créditos por curso.** Prolog los necesita para la regla de balance. Racket ya exportaba `creditos` en cada curso desde la Etapa 2, así que no hubo que ajustar nada.

## Decisiones de diseño

### Cómo se modelaron las combinaciones

`carga.pl` convierte cada combinación en un hecho dinámico con términos compuestos y listas:

```prolog
combinacion(Id, CreditosTotales, [curso(Codigo, Grupo, Carrera, Area, Creditos), ...])
rango_creditos(Min, Max)
```

- Los textos del JSON (código, carrera, área) pasan a **átomos**. Así se comparan por unificación y se escriben tal cual como hechos en `politica.pl` (`'Ing.Computadores'`, `'SE1400'`).
- Cada combinación recibe un `Id` secuencial. Es lo que permite recorrerlas por backtracking y que Java identifique cada resultado.
- Se usa un término `curso/5` en vez de varios hechos sueltos porque una regla necesita ver **toda la combinación a la vez** (por ejemplo, contar cursos de un área).
- Los hechos son dinámicos (`assertz`) solo para guardar la entrada. Las reglas no usan `assert/retract`: el estado viaja por argumentos.

### Cómo se asignó el área

El área es la **unidad académica que imparte el curso**, y se reconoce por el **prefijo de letras del código**, con una tabla en `area.c` (una fila por prefijo):

| Prefijo | Área | Ejemplo en los planes |
|---|---|---|
| `CE` | Computadores | CE1101 Introducción a la Programación (plan Computadores) |
| `MA` | Matematica | MA1102 Cálculo Diferencial e Integral (ambos planes) |
| `MI` | Mantenimiento Industrial | cursos `MI31xx` (plan Mantenimiento) |
| `FI` / `QU` | Fisica / Quimica | FI1201 Laboratorio de Física General I / QU1106 Química Básica I |
| `SE` | Actividades Culturales y Deportivas | SE1100 Actividad Cultural I, SE1200 Actividad Deportiva I |
| `CI` | Idiomas y Comunicacion | CI0202 Inglés Básico, CI1230 Inglés I (plan Mantenimiento) |

**Por qué por prefijo y no por una lista manual:**
- Es automático para los dos planes (más de 100 cursos) y no hay que clasificar curso por curso.
- Refleja la realidad institucional: el prefijo ya identifica a la escuela que lo imparte.
- Un prefijo que no está en la tabla **funciona como su propia área** (en mayúsculas) y un código sin letras da `SinArea`. Así nunca falla ni hay que tocar el código para un prefijo nuevo.
- Los nombres de área no llevan tildes para usarlos sin problema como átomos en Prolog y como llaves en Java.

`politica.pl` tiene un `max_cursos_area/2` por cada área de la tabla y `max_cursos_area_defecto/1` para las que no tengan hecho propio.

### Qué pares se declararon incompatibles y por qué

```prolog
par_incompatible('SE1100', 'SE1400').   % Actividad Cultural I vs Actividad Cultural-Deportiva
par_incompatible('SE1200', 'SE1400').   % Actividad Deportiva I vs Actividad Cultural-Deportiva
par_incompatible('CI0202', 'CI1230').   % Inglés Básico vs Inglés I (solo plan Mantenimiento)
```

- **SE1100-SE1400 y SE1200-SE1400:** `SE1400` es una actividad cultural-deportiva, que cubre lo mismo que las dos actividades separadas. Llevarla junto con cualquiera de las otras es redundante.
- **CI0202-CI1230:** Inglés Básico es una nivelación y Inglés I es el nivel regular; no tiene sentido matricular ambos a la vez.
- **Criterio de elección:** ambos cursos deben estar en el **mismo plan** y poder matricularse **al mismo tiempo**. Un par como MA1102-MA1103 (el segundo exige haber aprobado el primero) nunca aparece junto en una combinación, así que no probaría nada.
- Cada par se declara **una sola vez**, en un solo sentido. La **simetría** la resuelve `reglas.pl` con `incompatibles/2`, no se repite en los hechos.

### Caso donde el orden de las reglas cambia la razón

`razon/2` revisa las reglas en este orden: **balance → área → incompatibilidad**. Se eligió de lo más general (afecta a toda la combinación) a lo más específico (un par concreto).

Ejemplo: una combinación con `SE1100`, `SE1400` y `SE1200` rompe **dos** reglas a la vez:
- Límite por área: son 3 cursos de `Actividades Culturales y Deportivas` y el máximo es 2.
- Incompatibilidad: `SE1100`-`SE1400` (y `SE1200`-`SE1400`).

```prolog
?- razon([curso('SE1100',1,'Ing.Computadores','Actividades Culturales y Deportivas',1),
          curso('SE1400',1,'Ing.Computadores','Actividades Culturales y Deportivas',1),
          curso('SE1200',1,'Ing.Computadores','Actividades Culturales y Deportivas',1)], R).
R = area('Actividades Culturales y Deportivas', 3, 2).
```

Con el orden actual la razón es **área**. Si se invirtiera el orden de las cláusulas de `razon/2` (incompatibilidad antes que área), la misma combinación se reportaría como `incompatibilidad('SE1100','SE1400')`. Por eso el orden es parte del diseño y está cubierto en `tests/reglas_test.pl` (`orden_de_reglas`).

### Corte y negación por falla (justificación)

- **Negación por falla en `cumple_*`:** "cumple" se define como "**no existe** ninguna violación": `cumple_balance(C) :- \+ carrera_excedida(C, _, _, _).` Así cada regla se escribe **una sola vez** como *testigo de la violación* (`carrera_excedida/4`, `area_excedida/4`, `par_en_conflicto/3`) y el booleano sale gratis, sin duplicar lógica.
- **Corte en `razon/2`:** cada cláusula termina con `!` para **fijar la primera razón** y evitar que el backtracking ofrezca otras. Sin los cortes, una combinación con varias violaciones daría varias respuestas y la "primera regla violada" dejaría de estar bien definida. La primera cláusula (`cumple`) también corta para no seguir buscando razones en una combinación válida.
- **Corte en `veredicto/2`:** si `cumple_politica` triunfa se corta y no se intenta la cláusula `false`.
- `razon_indeterminada` es la cláusula de respaldo: no debería alcanzarse mientras las tres reglas estén completas.

### Caso límite real

El enunciado define que una combinación con cursos de **una sola carrera** es válida mientras no supere su máximo. Como cada ejecución de C carga **un solo catálogo** (el de la carrera del estudiante), **todas** las combinaciones traen una sola carrera, y esa carrera siempre aporta el 100 % de los créditos. Con un máximo menor que 100 se rechazarían **todas** las combinaciones por balance, aunque nada esté mal.

Se resolvió así:
- Los hechos base de `max_porcentaje_carrera/2` valen **100** para las dos carreras, de modo que la regla no rechaza combinaciones de una sola carrera.
- La regla compara con **enteros** (`Parte * 100 > Maximo * Total`) en vez de dividir. Así una combinación con 0 créditos totales no produce división entre cero y un 50 % exacto no se pasa por redondeo.
- La regla sigue siendo plenamente funcional: durante la defensa se puede bajar el porcentaje en `politica.pl`, o probarla con combinaciones de varias carreras, sin tocar `reglas.pl`.

Otros dos casos límite que maneja `carga.pl`: un campo faltante lanza un error que dice **cuál campo y en qué combinación**, y si `creditosTotales` no coincide con la suma de los cursos se emite una advertencia (la decisión sobre la combinación queda a las reglas).

### Justificación del formato de salida

El formato es **JSON**, por consistencia con todo el proyecto (el catálogo de C, el historial, las preferencias y la salida de Racket) y porque Java lo lee con cualquier librería estándar. El archivo se escribe en UTF-8.

```json
{
  "cantidad": 147,
  "entrada": "Output/combinaciones.json",
  "resultados": [
    {
      "id": 1,
      "pares": [ { "curso": "CE2103", "grupo": 1 }, { "curso": "MA0101", "grupo": 2 } ],
      "creditosTotales": 6,
      "cumple": true,
      "razon": "cumple"
    }
  ]
}
```

Los campos que pide el enunciado son `pares` (lista curso-grupo), `cumple` (booleano) y `razon` (primera regla violada, o `"cumple"`). Se agregaron, y se justifican por quien consume el archivo:

- `id`: identifica cada combinación y la relaciona con la del archivo de Racket.
- `creditosTotales`: Java puede mostrarlo sin recalcularlo.
- `razon` como **texto legible** (por ejemplo `Limite por area: Matematica tiene 3 cursos y el máximo es 2`): Java lo muestra tal cual, sin traducir términos de Prolog.
- `entrada` y `cantidad` en la raíz: dejan registrado de qué archivo salió y cuántas combinaciones se evaluaron.

## Representación de datos y predicados principales

**Datos**

| Término | Dónde | Significado |
|---|---|---|
| `combinacion(Id, Creditos, Cursos)` | `carga.pl` (dinámico) | Una combinación recibida de Racket |
| `curso(Codigo, Grupo, Carrera, Area, Creditos)` | dentro de `Cursos` | Un curso con su grupo elegido |
| `rango_creditos(Min, Max)` | `carga.pl` (dinámico) | Rango con que Racket generó el archivo |
| `max_porcentaje_carrera(Carrera, P)` | `politica.pl` | Máximo % de créditos por carrera |
| `max_cursos_area(Area, N)` | `politica.pl` | Máximo de cursos por área |
| `par_incompatible(A, B)` | `politica.pl` | Par declarado una sola vez |

**Predicados**

| Predicado | Qué hace |
|---|---|
| `cumple_politica/1` | La combinación cumple las tres reglas |
| `cumple_balance/1`, `cumple_limite_area/1`, `cumple_incompatibilidad/1` | Una regla, con negación por falla |
| `carrera_excedida/4`, `area_excedida/4`, `par_en_conflicto/3` | El **testigo** de la violación |
| `incompatibles/2` | Relación simétrica de incompatibilidad |
| `razon/2` | Primera regla violada (con corte) |
| `razon_texto/2`, `veredicto/2` | Razón en texto y booleano para el JSON |

### Ejemplos de consulta en más de un modo

**`incompatibles/2`** (relación simétrica, se usa en cuatro modos):

```prolog
?- incompatibles('SE1100', 'SE1400').     % comprobar un par
true.

?- incompatibles('SE1400', X).            % dado un curso, encontrar sus incompatibles
X = 'SE1100' ;
X = 'SE1200'.

?- incompatibles(X, 'SE1400').            % con el curso fijo en la segunda posición
X = 'SE1100' ;
X = 'SE1200'.

?- incompatibles(X, Y).                   % enumerar toda la relación (cada par dos veces)
X = 'SE1100', Y = 'SE1400' ;
...
```

**`area_excedida/4`** (comprobar o descubrir):

```prolog
?- C = [curso('MA1102',1,'Ing.Computadores','Matematica',4),
        curso('MA1103',1,'Ing.Computadores','Matematica',4),
        curso('MA2104',1,'Ing.Computadores','Matematica',4)],
   area_excedida(C, 'Matematica', N, M).     % comprobar un área concreta
N = 3, M = 2.

?- C = [curso('MA1102',1,'Ing.Computadores','Matematica',4),
        curso('MA1103',1,'Ing.Computadores','Matematica',4),
        curso('MA2104',1,'Ing.Computadores','Matematica',4)],
   area_excedida(C, A, N, M).                % descubrir qué área se excede
A = 'Matematica', N = 3, M = 2.
```

`carrera_excedida/4` funciona igual: con la carrera sin instanciar enumera las excedidas.

**`razon/2`** también se usa en dos modos: con la razón libre devuelve la primera violada, y con la razón instanciada comprueba si es esa (`razon(Cursos, cumple)`).

## Pruebas (Etapa 3)

- `tests/carga_test.pl`: hechos de política (valores por defecto, pares declarados una sola vez, porcentajes en rango) y carga (conteo, forma de los términos, errores de archivo). Usa archivos temporales, no depende de `Output/`.
- `tests/reglas_test.pl` (38 pruebas): combinaciones armadas a mano. Cubre los auxiliares de créditos, las tres reglas (incluidos los modos comprobar/enumerar), la simetría de `incompatibles/2`, que cada par se reporte una sola vez, que `razon/2` sea determinista (el corte), **el caso del orden de reglas** y el texto de la razón.

## Limitaciones conocidas (Etapa 3)

- **Con un solo catálogo por ejecución, la regla de balance no puede rechazar** mientras el máximo sea 100 (ver caso límite). Para ver un rechazo por balance hay que bajar el porcentaje en `politica.pl`.
- `razon/2` solo reporta la **primera** regla violada; no lista todas las que se incumplen.
- Los valores de `politica.pl` son parámetros de ejemplo, coherentes con los catálogos actuales; el enunciado indica que pueden cambiar durante la defensa y bastaría editar ese archivo.
- `par_en_conflicto/3` recorre todos los pares de cursos de la combinación (cuadrático), suficiente para combinaciones de pocos cursos.

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

flujo.rkt     → streams perezosos con tipos (Streamof), usados por todos los módulos de arriba
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

Sin argumentos, `main.rkt` usa el catálogo y las preferencias del estudiante 1. Hay un ejemplo de preferencias para cada estudiante en `Estudiantes/Preferencias/`. El catálogo con el que se corre debe corresponder a la carrera del estudiante (por ejemplo, `PreferenciasEstudiante2.json` pide cursos de Mantenimiento), porque `validarPreferencias` falla si un curso de interés no existe en el catálogo cargado.

## Formato del archivo de preferencias

```json
{
  "intereses": [
    { "curso": "MA0101", "grupos": [1, 2, 3] },
    { "curso": "QU1102", "grupos": [] }
  ],
  "creditosMin": 8,
  "creditosMax": 14
}
```

Cada interés es un curso con los grupos que el estudiante acepta. Una lista vacía significa que acepta cualquier grupo del curso. Los créditos mínimo y máximo definen el rango del filtro.

## Decisiones de diseño

### Justificación de decisiones propias

1. **Se generan subconjuntos de los cursos de interés, no solo la lista completa.** Si el programa exigiera un grupo por *cada* curso de la lista, todas las combinaciones sumarían los mismos créditos y el filtro por rango no descartaría nada. Al tratar la lista como un conjunto de cursos posibles, el rango de créditos es lo que decide qué horarios sirven. `subconjuntos` es perezosa: producir el primer subconjunto de una lista de 40 cursos no recorre los 2^40. El subconjunto vacío se descarta, porque no es un horario.
2. **Racket no recalcula requisitos ni choques.** Usa el campo `puedeMatricular` (solo el valor `1`) y la lista `choques` que ya calculó C. El booleano `choca` de cada grupo se lee y se guarda en la struct `Grupo`, pero no se usa para decidir: un grupo que choca con *algún* otro puede ser perfectamente compatible con los demás grupos elegidos, y solo la lista de pares responde esa pregunta. Esto sigue la división de responsabilidades de las etapas y evita tener dos implementaciones de la misma regla que se puedan contradecir.
3. **Poda temprana de choques.** En `combinaciones.rkt`, `probar-opciones` revisa si cada grupo choca con los ya elegidos *antes* de seguir con los cursos restantes, así que una rama con choque nunca se completa.
4. **Inmutabilidad.** No se usa `set!`, estructuras mutables ni variables globales reasignadas. El estado se lleva con parámetros de recursión: la lista `elegidos` al generar y el contador `cantidad` al exportar.
5. **Una función polimórfica reutilizada.** `filtrar` y `filtrar-rango-creditos` tienen tipo `(All (A) ...)` y reciben la función que obtiene los créditos. En `main.rkt` se usan con `Combinacion`; en las pruebas, también con enteros y con strings. `subconjuntos` también es polimórfica.
6. **Streams propios en `flujo.rkt`.** Typed Racket no trae tipos para `racket/stream`, así que se definió un tipo `Streamof` con una celda (primer elemento) y una promesa (`delay`/`force`) que calcula el resto solo cuando alguien lo pide. Así los streams se pueden usar con tipos explícitos en todo el proyecto, con las operaciones que se necesitan (`stream-map`, `stream-filter`, `stream-append`, `stream-take`, `stream->list`). `stream->list` solo se usa en las pruebas; el programa principal nunca materializa la lista completa. La promesa guarda su resultado internamente, y esa memoización es la única forma de estado oculto: el código del proyecto no usa mutación explícita.
7. **Tipos explícitos en todo el código** (`#lang typed/racket`). Además, `jsonUtil.rkt` valida el tipo de cada campo del JSON antes de usarlo y falla con un mensaje claro si falta o es de otro tipo.

### Caso límite real que encontramos

En una versión anterior del archivo de preferencias de ejemplo, el estudiante 1 pedía CE1101 y CE1104, pero ya los tenía aprobados (`puedeMatricular = 2`), y además sumaban 6 créditos con un mínimo de 12. El resultado era un archivo vacío sin ninguna explicación.

Se resolvió así: `cursos-omitidos` detecta los cursos de interés que no se pueden matricular, `ejecutar` avisa por `stderr` cuáles se ignoraron, y la generación sigue con los demás. Si ninguna combinación cumple el rango, el archivo igual se escribe como JSON válido con `"combinaciones": []`, para que la etapa siguiente no falle. El `PreferenciasEstudiante1.json` actual conserva CE1101 a propósito (con el grupo 1), para mostrar este aviso al ejecutar.

### Justificación del formato de salida

El formato es **JSON**, y se escribe **combinación por combinación**. Esta segunda decisión viene de usar streams: como las combinaciones se producen una a una, el exportador las escribe apenas aparecen y nunca guarda la lista completa en memoria. Con JSON eso se logra escribiendo `[`, cada objeto separado por coma y `]`. Además, JSON ya se usa en todo el proyecto (el catálogo de C, el historial, las preferencias), y Prolog puede leerlo con `library(http/json)`.

Ejemplo ilustrativo del archivo de salida (para un rango de 6 a 14 créditos):

```json
{
  "creditosMin": 6,
  "creditosMax": 14,
  "combinaciones": [
    {
      "creditosTotales": 7,
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

La carrera de cada curso se copia tal cual del campo `carrera` del catálogo que exporta C. Ver las limitaciones para el alcance de este campo.

## Estructuras de datos desarrolladas (Etapa 2)

Definidas en `tipos.rkt` y `flujo.rkt`. Todas son `struct` inmutables:

- **`Bloque`**, **`Grupo`**, **`Curso`**, **`ParChoque`** y **`Catalogo`**: reflejan el JSON que exporta C (ver la sección de la Etapa 1).
- **`Interes`**: un curso que le interesa al estudiante y los grupos que acepta. Si la lista de grupos está vacía, acepta cualquiera.
- **`Preferencias`**: la lista de `Interes` y los créditos mínimos y máximos.
- **`Seleccion`**: un `Curso` junto con el `Grupo` elegido.
- **`Combinacion`**: una lista de `Seleccion` (una por curso) y sus créditos totales.
- **`Streamof`** (en `flujo.rkt`): un stream es vacío (`Vacio`) o una celda (`Celda`) con su primer elemento y una promesa que calcula el resto. Las combinaciones nunca se guardan como lista completa: se generan, filtran y escriben de una en una.

## Uso de streams

La generación completa es un pipeline de streams: `subconjuntos` → `combinaciones-por-subconjunto` → `stream-map armar-combinacion` → `filtrar-rango-creditos` → `escribir-combinaciones`. Ninguna etapa construye la lista completa de combinaciones; el único consumidor que recorre todo el stream es el exportador, que escribe cada elemento y lo suelta.

## Pruebas

`tests/pruebas.rkt` usa un catálogo pequeño armado a mano (con un choque conocido y un curso no matriculable), así que no depende de ningún archivo. Prueban: los subconjuntos, la omisión de cursos no habilitados, que no haya combinaciones con choques, el filtro por créditos con distintos tipos de dato, y el JSON exportado (incluido el caso sin combinaciones).

## Limitaciones conocidas (Etapa 2)

- **La carrera de cada curso es la del estudiante.** C carga un solo catálogo por ejecución y asigna a todos sus cursos la carrera del historial del estudiante. Por eso, en una misma corrida, todos los cursos de la salida de Racket llevan la misma carrera. Racket exporta el campo sin modificarlo.
- **No se valida que un curso aparezca una sola vez en las preferencias.** Si el archivo repite un curso, el programa podría generar combinaciones con ese curso dos veces.
- Si el estudiante deja `"grupos": []` en varios cursos con muchos grupos (por ejemplo MA0101 tiene 11 y QU1102 tiene 13), el número de combinaciones crece rápido. Se escriben igual, pero el archivo puede ser grande; conviene listar solo los grupos que realmente le sirven.
- `hay-choque?` busca cada par en la lista completa de choques. Es suficiente para los catálogos actuales, pero un índice por par sería más rápido con catálogos más grandes.
- Si un curso o grupo de las preferencias no existe en el catálogo, el programa termina con error en lugar de omitirlo.

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

- **`Bloque`**: un tramo de horario: día, hora de inicio y hora de fin. Un grupo puede tener varios bloques (por ejemplo, un curso que se reúne martes y jueves).
- **`Grupo`**: número de grupo, profesor, su arreglo de `Bloque`, y un booleano `choca` que resume si tiene algún conflicto de horario con otro grupo del catálogo.
- **`Curso`**: código, nombre, carrera (se toma del historial del estudiante, por eso los JSON del catálogo no la repiten), área (se calcula del prefijo del código con `area.c`; se agregó en la Etapa 3), créditos, arreglos de nombres de requisitos y correquisitos, su arreglo de `Grupo`, y `puedeMatricular` (el resultado de la evaluación de elegibilidad).
- **`ParChoque`**: identifica un par específico de grupos que chocan entre sí (código de curso y número de grupo de cada lado).
- **`Catalogo`**: el arreglo completo de `Curso`, más el arreglo de `ParChoque` detectados y su cantidad.
- **`Estudiante`**: carnet, nombre, carrera (usada para elegir el catálogo), y el arreglo de códigos de los cursos que ya aprobó.

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

`Output/catalogoExp.json` contiene, por cada curso: código, nombre, carrera, área, créditos, `puedeMatricular`, requisitos, correquisitos, y su arreglo de grupos (cada uno con número, profesor, si choca, y sus bloques de horario). Además incluye un arreglo `"choques"` con la lista completa de pares de grupos detectados como incompatibles (sujeta al límite `MAX_CHOQUES` descrito arriba).

## Datos de entrada

Los datos de ambas carreras (Computadores en `Horarios/compu.json`, Mantenimiento Industrial en `Horarios/mante.json`) fueron recolectados de la Guía de Horarios institucional del TEC, cubriendo del semestre 0 al 8 de cada plan de estudios, con los horarios de Cartago del primer semestre de 2026. Los historiales de estudiantes se esperan como archivos JSON individuales (por ejemplo en una carpeta `Estudiantes/`), cada uno con carnet, nombre, carrera y la lista de códigos de cursos ya aprobados.

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