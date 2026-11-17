%% razon.pl: determina la primera regla de politica que incumple una combinacipon. El orden es: balance, límite por área, incompatibilidad

:- module(razon, [
    razon/2,
    razon_texto/2,
    veredicto/2
]).

:- use_module(reglas).

%% razon(+Cursos, -Razon)
%%   Modo principal: recibe la lista curso/5 y devuelve el primer motivo
%%   Se usa corte en cada violación para detener el backtracking y fijar una sola razon, según el orden establecido
razon(Cursos, cumple) :-
    cumple_politica(Cursos),
    !.
razon(Cursos, balance(Carrera, Creditos, Maximo)) :-
    carrera_excedida(Cursos, Carrera, Creditos, Maximo),
    !.
razon(Cursos, area(Area, Cantidad, Maximo)) :-
    area_excedida(Cursos, Area, Cantidad, Maximo),
    !.
razon(Cursos, incompatibilidad(A, B)) :-
    par_en_conflicto(Cursos, A, B),
    !.
razon(_, razon_indeterminada) :-
    %% No debe alcanzarse si las reglas están completas
    !.

%% Esta funión convierte el término de razón a una cadena legible para Java y el JSON
razon_texto(Cursos, Texto) :-
    razon(Cursos, Razon),
    razon_a_texto(Razon, Texto).

%% Predicado booleano auxiliar en modo fijo
veredicto(Cursos, true) :-
    cumple_politica(Cursos),
    !.
veredicto(_, false).

razon_a_texto(cumple, 'cumple').
razon_a_texto(balance(Carrera, Creditos, Maximo), Texto) :-
    format(string(Texto),
           'Balance entre carreras: ~w tiene ~d créditos y excede el máximo de ~d%',
           [Carrera, Creditos, Maximo]).
razon_a_texto(area(Area, Cantidad, Maximo), Texto) :-
    format(string(Texto),
           'Limite por area: ~w tiene ~d cursos y el máximo es ~d',
           [Area, Cantidad, Maximo]).
razon_a_texto(incompatibilidad(A, B), Texto) :-
    format(string(Texto),
           'Incompatibilidad: los cursos ~w y ~w aparecen juntos',
           [A, B]).
razon_a_texto(razon_indeterminada, 'razón indeterminada').
