%% carga.pl: carga de las combinaciones que genera Racket (Etapa 2).
%%
%% Lee Output/combinaciones.json y lo convierte en hechos dinamicos
%% combinacion/3 cuyos argumentos son terminos compuestos, de modo que las
%% etapas siguientes recorran todas las combinaciones
%%
%%   combinacion(Id, CreditosTotales, [curso(Codigo, Grupo, Carrera, Area, Creditos), ...])
%%
%% Tambien se guarda el rango con el que Racket genero el archivo:
%%
%%   rango_creditos(Min, Max)


:- module(carga, [
    cargar_combinaciones/1,
    cargar_combinaciones/2,
    limpiar_combinaciones/0,
    combinacion/3,
    rango_creditos/2
]).

:- use_module(library(http/json)).
:- use_module(library(error)).
:- use_module(library(lists)).
:- use_module(library(aggregate)).

:- dynamic combinacion/3.
:- dynamic rango_creditos/2.

%% cargar_combinaciones(+Ruta)
%%   Version sin contador, para usar desde la linea de comandos o main.pl.
cargar_combinaciones(Ruta) :-
    cargar_combinaciones(Ruta, _).

%% cargar_combinaciones(+Ruta, -Total)
%%   Reemplaza lo que hubiera cargado antes por el contenido de Ruta y
%%   devuelve cuantas combinaciones cargo. La operacion es atomica respecto a
%%   la base de datos: primero se lee y valida TODO el archivo y solo despues
%%   se escriben los hechos, asi un archivo defectuoso no deja una carga a
%%   medias ni borra la anterior.
cargar_combinaciones(Ruta, Total) :-
    leer_json(Ruta, Raiz),
    campo(Raiz, creditosMin, Min, 'raiz'),
    campo(Raiz, creditosMax, Max, 'raiz'),
    must_be(integer, Min),
    must_be(integer, Max),
    campo(Raiz, combinaciones, Lista, 'raiz'),
    must_be(list, Lista),
    convertir_lista(Lista, 1, Terminos),
    limpiar_combinaciones,
    assertz(rango_creditos(Min, Max)),
    registrar(Terminos),
    length(Terminos, Total).

%% limpiar_combinaciones
%%   Borra las combinaciones y el rango cargados.
limpiar_combinaciones :-
    retractall(combinacion(_, _, _)),
    retractall(rango_creditos(_, _)).

%% ---------------------------------------------------------------------------
%% Lectura
%% ---------------------------------------------------------------------------

%% leer_json(+Ruta, -Dict)
%%   El archivo se lee como UTF-8. Si no existe, open/4 lanza existence_error;
%%   si no es JSON valido, json_read_dict/2 lanza syntax_error.
leer_json(Ruta, Dict) :-
    setup_call_cleanup(
        open(Ruta, read, Entrada, [encoding(utf8)]),
        json_read_dict(Entrada, Dict),
        close(Entrada)
    ).

%% ---------------------------------------------------------------------------
%% Conversion JSON -> terminos
%% ---------------------------------------------------------------------------

%% convertir_lista(+Jsons, +IdInicial, -Terminos)
convertir_lista([], _, []).
convertir_lista([Json|Jsons], Id, [Termino|Terminos]) :-
    convertir_combinacion(Json, Id, Termino),
    Id1 is Id + 1,
    convertir_lista(Jsons, Id1, Terminos).

%% convertir_combinacion(+Json, +Id, -Termino)
convertir_combinacion(Json, Id, combinacion(Id, Creditos, Cursos)) :-
    format(atom(Donde), 'combinacion ~d', [Id]),
    campo(Json, creditosTotales, Creditos, Donde),
    must_be(integer, Creditos),
    campo(Json, cursos, CursosJson, Donde),
    must_be(list, CursosJson),
    maplist(convertir_curso(Donde), CursosJson, Cursos),
    verificar_creditos(Id, Creditos, Cursos).

%% convertir_curso(+Donde, +Json, -Curso)
%%   Los textos pasan a atomos (para poder compararlos con unificacion y
%%   escribirlos como hechos en politica.pl) y los numeros se exigen enteros.
convertir_curso(Donde, Json, curso(Codigo, Grupo, Carrera, Area, Creditos)) :-
    campo(Json, curso,    CodigoTxt,  Donde),
    campo(Json, grupo,    Grupo,      Donde),
    campo(Json, carrera,  CarreraTxt, Donde),
    campo(Json, area,     AreaTxt,    Donde),
    campo(Json, creditos, Creditos,   Donde),
    must_be(integer, Grupo),
    must_be(integer, Creditos),
    atom_string(Codigo,  CodigoTxt),
    atom_string(Carrera, CarreraTxt),
    atom_string(Area,    AreaTxt).

%% verificar_creditos(+Id, +Declarados, +Cursos)
%%   Comprobacion de consistencia: los creditos totales deben ser la suma de
%%   los creditos de los cursos. Si no coinciden se avisa, pero no se rechaza
%%   el archivo: la decision sobre una combinacion corresponde a las reglas.
verificar_creditos(Id, Declarados, Cursos) :-
    aggregate_all(sum(C), member(curso(_, _, _, _, C), Cursos), Suma),
    (   Suma =:= Declarados
    ->  true
    ;   print_message(warning,
            format("combinacion ~d: creditosTotales=~d pero la suma de sus cursos es ~d",
                   [Id, Declarados, Suma]))
    ).

%% campo(+Dict, +Clave, -Valor, +Donde)
%%   Lee un campo obligatorio. Si falta, lanza un error que dice cual campo y
%%   en que parte del archivo, en vez de fallar en silencio.
campo(Dict, Clave, Valor, Donde) :-
    (   get_dict(Clave, Dict, V)
    ->  Valor = V
    ;   throw(error(existence_error(campo_json, Clave),
                    context(carga:campo/4, Donde)))
    ).

%% registrar(+Terminos)
%%   Escribe los hechos ya validados.
registrar([]).
registrar([Termino|Terminos]) :-
    assertz(Termino),
    registrar(Terminos).
