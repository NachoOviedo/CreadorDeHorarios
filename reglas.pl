%% reglas.pl: reglas de politica academica (Etapa 3, Prolog).
%%
%% Cada regla es un predicado que recibe la lista de cursos de UNA combinacion
%% (los mismos terminos curso/5 que carga.pl deja dentro de combinacion/3):
%%
%%   curso(Codigo, Grupo, Carrera, Area, Creditos)
%%
%% y TRIUNFA si la combinacion cumple la regla. Ninguna regla escribe valores
%% numericos propios: los limites se consultan siempre en politica.pl (por
%% medio de limite_porcentaje/2, limite_cursos_area/2 y par_incompatible/2),
%% de modo que cambiar un parametro durante la defensa solo exige editar ese
%% archivo.
%%
%% Cada regla se ofrece en dos niveles:
%%
%%   cumple_*   : la verificacion de si-o-no. Se define con negacion por falla:
%%                "cumple" significa "no existe ninguna violacion".
%%   *_excedida / par_en_conflicto : el TESTIGO de la violacion. Dicen cual
%%                carrera, area o par rompe la regla, para que razon.pl pueda
%%                explicar el rechazo sin duplicar la logica de validacion.
%%
%% Este modulo NO decide en que orden se revisan las reglas ni cual se reporta
%% primero: eso es responsabilidad de razon.pl (Feature 4).
%%
%% No se usa assert/retract ni variables globales: todo el estado viaja por
%% argumentos y unificacion.

:- module(reglas, [
    cumple_politica/1,
    cumple_balance/1,
    cumple_limite_area/1,
    cumple_incompatibilidad/1,
    carrera_excedida/4,
    area_excedida/4,
    par_en_conflicto/3,
    incompatibles/2,
    creditos_totales/2,
    creditos_de_carrera/3,
    excede_porcentaje/3
]).

:- use_module(library(lists)).
:- use_module(library(error)).
:- use_module(politica).

%% ---------------------------------------------------------------------------
%% Conjunto de las tres reglas
%% ---------------------------------------------------------------------------

%% cumple_politica(+Cursos)
%%   La combinacion cumple las TRES reglas. Es una conjuncion pura: no dice
%%   cual falla (para eso esta razon.pl), solo responde si todas se cumplen.
cumple_politica(Cursos) :-
    cumple_balance(Cursos),
    cumple_limite_area(Cursos),
    cumple_incompatibilidad(Cursos).

%% ---------------------------------------------------------------------------
%% Regla 1: balance entre carreras
%% ---------------------------------------------------------------------------
%% Cada carrera tiene un porcentaje maximo de los CREDITOS TOTALES de la
%% combinacion. La regla se incumple si alguna carrera supera su maximo.
%% Una combinacion con cursos de una sola carrera tiene el 100% de sus
%% creditos en ella, asi que solo es valida si el maximo de esa carrera es 100.

%% cumple_balance(+Cursos)
%%   Ninguna carrera supera su porcentaje maximo.
cumple_balance(Cursos) :-
    \+ carrera_excedida(Cursos, _, _, _).

%% carrera_excedida(+Cursos, ?Carrera, -CreditosCarrera, -MaxPorcentaje)
%%   Carrera aporta CreditosCarrera creditos a la combinacion y eso supera su
%%   MaxPorcentaje. Con Carrera sin instanciar enumera, por backtracking, todas
%%   las carreras excedidas; con Carrera instanciada solo comprueba esa.
carrera_excedida(Cursos, Carrera, CreditosCarrera, MaxPorcentaje) :-
    must_be(list, Cursos),
    creditos_totales(Cursos, Total),
    carreras_presentes(Cursos, Carreras),
    member(Carrera, Carreras),
    creditos_de_carrera(Cursos, Carrera, CreditosCarrera),
    limite_porcentaje(Carrera, MaxPorcentaje),
    excede_porcentaje(CreditosCarrera, Total, MaxPorcentaje).

%% excede_porcentaje(+Parte, +Total, +MaxPorcentaje)
%%   Parte es MAS del MaxPorcentaje por ciento de Total.
%%   Se compara Parte*100 > Max*Total, con enteros, en vez de dividir:
%%     - no hay division entre cero cuando Total es 0 (caso real: una
%%       combinacion formada solo por actividades SE, que valen 0 creditos;
%%       ahi 0*100 > Max*0 es falso y la regla se cumple),
%%     - no hay errores de redondeo en los casos justo en el limite.
excede_porcentaje(Parte, Total, MaxPorcentaje) :-
    Parte * 100 > MaxPorcentaje * Total.

%% creditos_totales(+Cursos, -Total)
%%   Suma de los creditos de todos los cursos de la combinacion.
creditos_totales(Cursos, Total) :-
    findall(C, member(curso(_, _, _, _, C), Cursos), Creditos),
    sum_list(Creditos, Total).

%% creditos_de_carrera(+Cursos, +Carrera, -Suma)
%%   Suma de los creditos de los cursos que pertenecen a Carrera. Carrera debe
%%   venir instanciada: sin instanciar sumaria los cursos de todas las carreras.
creditos_de_carrera(Cursos, Carrera, Suma) :-
    findall(C, member(curso(_, _, Carrera, _, C), Cursos), Creditos),
    sum_list(Creditos, Suma).

%% ---------------------------------------------------------------------------
%% Regla 2: limite por area
%% ---------------------------------------------------------------------------
%% Una combinacion no puede incluir mas de N cursos de una misma area, con N
%% tomado de politica.pl para cada area.

%% cumple_limite_area(+Cursos)
%%   Ninguna area supera su maximo de cursos.
cumple_limite_area(Cursos) :-
    \+ area_excedida(Cursos, _, _, _).

%% area_excedida(+Cursos, ?Area, -Cantidad, -Maximo)
%%   Hay Cantidad cursos de Area en la combinacion y el maximo es Maximo.
%%   Igual que carrera_excedida/4: enumera con Area libre, comprueba con Area
%%   instanciada.
area_excedida(Cursos, Area, Cantidad, Maximo) :-
    must_be(list, Cursos),
    areas_presentes(Cursos, Areas),
    member(Area, Areas),
    findall(Codigo, member(curso(Codigo, _, _, Area, _), Cursos), DeEstaArea),
    length(DeEstaArea, Cantidad),
    limite_cursos_area(Area, Maximo),
    Cantidad > Maximo.

%% ---------------------------------------------------------------------------
%% Regla 3: incompatibilidad
%% ---------------------------------------------------------------------------
%% Una combinacion no puede incluir los dos cursos de un par declarado
%% incompatible. La relacion es SIMETRICA, aunque politica.pl declare cada par
%% una sola vez y en un solo sentido.

%% cumple_incompatibilidad(+Cursos)
%%   Ningun par de cursos de la combinacion es incompatible.
cumple_incompatibilidad(Cursos) :-
    \+ par_en_conflicto(Cursos, _, _).

%% par_en_conflicto(+Cursos, ?A, ?B)
%%   A y B estan los dos en la combinacion y son incompatibles. Cada par se
%%   reporta UNA sola vez, con A @< B (orden estandar de terminos), y no como
%%   A-B y tambien B-A.
par_en_conflicto(Cursos, A, B) :-
    must_be(list, Cursos),
    member(curso(A, _, _, _, _), Cursos),
    member(curso(B, _, _, _, _), Cursos),
    A @< B,
    once(incompatibles(A, B)).

%% incompatibles(?A, ?B)
%%   Version simetrica de par_incompatible/2: A y B son incompatibles si el
%%   par esta declarado en cualquiera de los dos sentidos. Se puede consultar
%%   en varios modos:
%%     incompatibles(a, b)   comprueba un par
%%     incompatibles(a, X)   lista los incompatibles con a
%%     incompatibles(X, b)   lo mismo, con el curso fijo en la segunda posicion
%%     incompatibles(X, Y)   enumera la relacion completa (cada par dos veces,
%%                           una por sentido, porque la relacion es simetrica)
incompatibles(A, B) :-
    par_incompatible(A, B).
incompatibles(A, B) :-
    par_incompatible(B, A).

%% ---------------------------------------------------------------------------
%% Auxiliares
%% ---------------------------------------------------------------------------

%% carreras_presentes(+Cursos, -Carreras)
%%   Las carreras que aparecen en la combinacion, sin repetir. sort/2 elimina
%%   duplicados, asi cada carrera se evalua una sola vez.
carreras_presentes(Cursos, Carreras) :-
    findall(Carrera, member(curso(_, _, Carrera, _, _), Cursos), Todas),
    sort(Todas, Carreras).

%% areas_presentes(+Cursos, -Areas)
%%   Las areas que aparecen en la combinacion, sin repetir.
areas_presentes(Cursos, Areas) :-
    findall(Area, member(curso(_, _, _, Area, _), Cursos), Todas),
    sort(Todas, Areas).
