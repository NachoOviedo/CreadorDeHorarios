%% reglas_test.pl: pruebas de reglas.pl y razon.pl.
%%
%% Ejecutar desde la raiz del proyecto:
%%   swipl -g run_tests -t halt tests/reglas_test.pl
%%
%% Las pruebas arman combinaciones a mano (terminos curso/5) y no dependen de
%% ningun archivo. Los limites salen de politica.pl: si se cambian alli, estas
%% pruebas deben ajustarse.

:- use_module(library(plunit)).
:- use_module('../politica').
:- use_module('../reglas').
:- use_module('../razon').

%% --- Combinaciones de prueba: curso(Codigo, Grupo, Carrera, Area, Creditos) ---

% valida: un curso de cada area, sin pares incompatibles
valida([curso('CE2103', 1, 'Ing.Computadores', 'Computadores', 4),
        curso('QU1106', 1, 'Ing.Computadores', 'Quimica', 3)]).

% 3 cursos de Matematica (maximo 2)
tres_mate([curso('MA1102', 1, 'Ing.Computadores', 'Matematica', 4),
           curso('MA1103', 1, 'Ing.Computadores', 'Matematica', 4),
           curso('MA2104', 1, 'Ing.Computadores', 'Matematica', 4)]).

% par incompatible SE1100-SE1400 (2 cursos del area: no excede el maximo)
con_par([curso('SE1100', 1, 'Ing.Computadores', 'Actividades Culturales y Deportivas', 1),
         curso('SE1400', 1, 'Ing.Computadores', 'Actividades Culturales y Deportivas', 1)]).

% viola dos reglas: area (3 > 2) e incompatibilidad (SE1100-SE1400)
dos_violaciones([curso('SE1100', 1, 'Ing.Computadores', 'Actividades Culturales y Deportivas', 1),
                 curso('SE1400', 1, 'Ing.Computadores', 'Actividades Culturales y Deportivas', 1),
                 curso('SE1200', 1, 'Ing.Computadores', 'Actividades Culturales y Deportivas', 1)]).

%% ---------------------------------------------------------------------------
:- begin_tests(auxiliares).

test(creditos_totales) :-
    valida(C), creditos_totales(C, 7).

test(creditos_totales_vacia) :-
    creditos_totales([], 0).

test(creditos_de_carrera) :-
    valida(C), creditos_de_carrera(C, 'Ing.Computadores', 7),
    creditos_de_carrera(C, 'Ing.Mantenimiento', 0).

test(excede_porcentaje_si) :-
    excede_porcentaje(6, 10, 50).            % 60% > 50%

test(excede_porcentaje_igual_no) :-
    \+ excede_porcentaje(5, 10, 50).         % 50% no supera 50%

test(excede_porcentaje_total_cero) :-
    \+ excede_porcentaje(0, 0, 100).         % sin division entre cero

:- end_tests(auxiliares).

%% ---------------------------------------------------------------------------
:- begin_tests(balance).

test(una_carrera_cumple_con_maximo_100) :-
    valida(C), cumple_balance(C).

test(combinacion_vacia_cumple) :-
    cumple_balance([]).

test(sin_carrera_excedida) :-
    valida(C), \+ carrera_excedida(C, _, _, _).

:- end_tests(balance).

%% ---------------------------------------------------------------------------
:- begin_tests(limite_area).

test(valida_cumple) :-
    valida(C), cumple_limite_area(C).

test(tres_de_matematica_no_cumple) :-
    tres_mate(C), \+ cumple_limite_area(C).

test(area_excedida_modo_comprobar) :-
    % Area instanciada: solo comprueba esa area
    tres_mate(C), area_excedida(C, 'Matematica', 3, 2).

test(area_excedida_modo_enumerar) :-
    % Area libre: la descubre
    tres_mate(C),
    findall(A-N-M, area_excedida(C, A, N, M), L),
    L == ['Matematica'-3-2].

test(area_no_excedida_modo_comprobar) :-
    valida(C), \+ area_excedida(C, 'Quimica', _, _).

:- end_tests(limite_area).

%% ---------------------------------------------------------------------------
:- begin_tests(incompatibilidad).

test(simetria) :-
    once(incompatibles('SE1100', 'SE1400')),
    once(incompatibles('SE1400', 'SE1100')).

test(modo_un_extremo_libre) :-
    findall(X, incompatibles('SE1400', X), L),
    sort(L, ['SE1100', 'SE1200']).

test(modo_enumerar_todo) :-
    % cada par sale dos veces (una por sentido)
    findall(A-B, par_incompatible(A, B), Declarados),
    findall(A-B, incompatibles(A, B), Todos),
    length(Declarados, N), length(Todos, M),
    M =:= 2 * N.

test(no_incompatibles) :-
    \+ incompatibles('CE2103', 'QU1106').

test(combinacion_con_par_no_cumple) :-
    con_par(C), \+ cumple_incompatibilidad(C).

test(par_se_reporta_una_sola_vez) :-
    con_par(C),
    findall(A-B, par_en_conflicto(C, A, B), L),
    L == ['SE1100'-'SE1400'].

test(valida_cumple) :-
    valida(C), cumple_incompatibilidad(C).

:- end_tests(incompatibilidad).

%% ---------------------------------------------------------------------------
:- begin_tests(politica_completa).

test(valida_cumple) :-
    valida(C), cumple_politica(C).

test(vacia_cumple) :-
    cumple_politica([]).

test(area_la_rompe) :-
    tres_mate(C), \+ cumple_politica(C).

test(par_la_rompe) :-
    con_par(C), \+ cumple_politica(C).

:- end_tests(politica_completa).

%% ---------------------------------------------------------------------------
:- begin_tests(razon).

test(cumple) :-
    valida(C), razon(C, cumple).

test(razon_area) :-
    tres_mate(C), razon(C, area('Matematica', 3, 2)).

test(razon_incompatibilidad) :-
    con_par(C), razon(C, incompatibilidad('SE1100', 'SE1400')).

test(orden_de_reglas) :-
    % La combinacion rompe area E incompatibilidad. Como area se revisa antes,
    % esa es la razon. Si el orden fuera el inverso, saldria incompatibilidad.
    dos_violaciones(C),
    razon(C, R),
    R = area('Actividades Culturales y Deportivas', 3, 2).

test(las_dos_reglas_estan_violadas) :-
    % confirma que el caso anterior realmente viola las dos reglas
    dos_violaciones(C),
    \+ cumple_limite_area(C),
    \+ cumple_incompatibilidad(C).

test(razon_es_determinista) :-
    % el corte deja exactamente una razon, aunque haya varias violaciones
    dos_violaciones(C),
    findall(R, razon(C, R), [_]).

test(razon_cumple_es_determinista) :-
    valida(C),
    findall(R, razon(C, R), [cumple]).

test(razon_texto_cumple) :-
    valida(C), razon_texto(C, Texto),
    Texto == 'cumple'.

test(razon_texto_area) :-
    tres_mate(C), razon_texto(C, Texto),
    sub_string(Texto, 0, _, _, "Limite por area").

test(razon_texto_incompatibilidad) :-
    con_par(C), razon_texto(C, Texto),
    sub_string(Texto, 0, _, _, "Incompatibilidad").

test(veredicto_true) :-
    valida(C), veredicto(C, true).

test(veredicto_false) :-
    tres_mate(C), veredicto(C, false).

test(veredicto_unico) :-
    % la clausula false no debe dar una segunda respuesta cuando cumple
    valida(C),
    findall(V, veredicto(C, V), [true]).

:- end_tests(razon).