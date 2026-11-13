%% politica.pl: hechos de la politica de matricula (Etapa 3, Prolog).
%%
%% Este modulo solo DECLARA datos. Las reglas que los aplican (balance entre
%% carreras, limite por area e incompatibilidad simetrica) viven en reglas.pl
%% y consultan estos hechos, de modo que cambiar la politica no obliga a
%% tocar ninguna regla: basta con editar este archivo.
%%
%% Convenciones:
%%   - Los codigos de curso, las carreras y las areas son atomos entre
%%     comillas simples, porque empiezan con mayuscula y de otro modo Prolog
%%     los leeria como variables.
%%   - Las carreras deben escribirse EXACTAMENTE como las exporta la Etapa 1
%%     (campo "carrera" del catalogo; ver CATALOGOS_POR_CARRERA en C).
%%   - Las areas deben escribirse EXACTAMENTE como las produce area.c
%%     (sin tildes), porque llegan tal cual en combinaciones.json.
%%   - Los porcentajes son enteros entre 0 y 100.
%%
%% NOTA: los valores numericos y los pares incompatibles de este archivo son
%% datos de ejemplo coherentes con los catalogos actuales. Deben contrastarse
%% con lo que pida el enunciado antes de la defensa.

:- module(politica, [
    max_porcentaje_carrera/2,
    max_porcentaje_defecto/1,
    limite_porcentaje/2,
    max_cursos_area/2,
    max_cursos_area_defecto/1,
    limite_cursos_area/2,
    par_incompatible/2
]).

%% ---------------------------------------------------------------------------
%% Balance entre carreras
%% ---------------------------------------------------------------------------

%% max_porcentaje_carrera(+Carrera, -Porcentaje)
%%   Porcentaje maximo de los CREDITOS TOTALES de una combinacion que pueden
%%   pertenecer a Carrera (no se cuentan cursos, se cuentan creditos).
%%   Una combinacion con cursos de una sola carrera tiene el 100% de sus
%%   creditos en esa carrera, asi que solo es valida si el maximo es 100.
%%   Por eso el valor base es 100: con los catalogos actuales cada ejecucion
%%   trae una sola carrera y un valor menor rechazaria todas las combinaciones
%%   por esta regla. La regla se demuestra con valores menores (por ejemplo
%%   durante la defensa) o con combinaciones de varias carreras.
max_porcentaje_carrera('Ing.Computadores',  100).
max_porcentaje_carrera('Ing.Mantenimiento', 100).

%% max_porcentaje_defecto(-Porcentaje)
%%   Se usa para una carrera que no tenga hecho propio.
max_porcentaje_defecto(100).

%% limite_porcentaje(+Carrera, -Porcentaje)
%%   Resuelve el limite aplicable: el hecho propio si existe y, si no, el
%%   valor por defecto. Es el unico predicado que las reglas deben usar.
limite_porcentaje(Carrera, Porcentaje) :-
    (   max_porcentaje_carrera(Carrera, P)
    ->  Porcentaje = P
    ;   max_porcentaje_defecto(Porcentaje)
    ).

%% ---------------------------------------------------------------------------
%% Maximo de cursos por area
%% ---------------------------------------------------------------------------

%% max_cursos_area(+Area, -Maximo)
%%   Cantidad maxima de cursos de una misma area dentro de una combinacion.
%%   Hay un hecho por cada area que reconoce area.c.
max_cursos_area('Computadores',                         3).
max_cursos_area('Computacion',                          2).
max_cursos_area('Mantenimiento Industrial',             3).
max_cursos_area('Matematica',                           2).
max_cursos_area('Fisica',                               2).
max_cursos_area('Quimica',                              2).
max_cursos_area('Electronica',                          2).
max_cursos_area('Administracion',                       1).
max_cursos_area('Produccion Industrial',                1).
max_cursos_area('Ciencias Sociales',                    1).
max_cursos_area('Ciencia de Materiales',                1).
max_cursos_area('Tecnologia de Materiales',             2).
max_cursos_area('Idiomas y Comunicacion',               1).
max_cursos_area('Seguridad Laboral',                    1).
max_cursos_area('Actividades Culturales y Deportivas',  2).

%% max_cursos_area_defecto(-Maximo)
%%   Se usa para un area que no tenga hecho propio (por ejemplo, un prefijo
%%   nuevo que area.c devuelva como su propia area).
max_cursos_area_defecto(2).

%% limite_cursos_area(+Area, -Maximo)
%%   Igual que limite_porcentaje/2: hecho propio o valor por defecto.
limite_cursos_area(Area, Maximo) :-
    (   max_cursos_area(Area, M)
    ->  Maximo = M
    ;   max_cursos_area_defecto(Maximo)
    ).

%% ---------------------------------------------------------------------------
%% Pares de cursos incompatibles
%% ---------------------------------------------------------------------------

%% par_incompatible(?CursoA, ?CursoB)
%%   Dos cursos que no pueden aparecer juntos en una combinacion.
%%   Cada par se declara UNA sola vez, en un solo sentido. La simetria
%%   (que A-B implique B-A) la resuelve reglas.pl, no se repite aqui.
%%
%%   Criterio para elegir pares: ambos cursos deben existir en el MISMO plan
%%   y poder matricularse a la vez (un par cuyo segundo curso exige haber
%%   aprobado el primero, como MA1102-MA1103, o con cursos de planes distintos,
%%   nunca aparece junto en una combinacion y no prueba nada).
%%
%%   Presentes en los dos planes (Computadores y Mantenimiento):
par_incompatible('SE1100', 'SE1400').   % actividad cultural vs cultural-deportiva (esta ya cubre ambas)
par_incompatible('SE1200', 'SE1400').   % actividad deportiva vs cultural-deportiva
%%   Solo en el plan de Mantenimiento:
par_incompatible('CI0202', 'CI1230').   % ingles basico (nivelacion) vs ingles I (nivel regular)
