%% carga_test.pl: pruebas de politica.pl y carga.pl.
%%
%% Ejecutar desde la raiz del proyecto:
%%   swipl -g run_tests -t halt tests/carga_test.pl
%%
%% Los archivos JSON de prueba se escriben en archivos temporales, asi que las
%% pruebas no dependen de Output/ ni de ningun otro archivo del repositorio.

:- use_module(library(plunit)).
:- use_module(library(http/json)).
:- use_module('../politica').
:- use_module('../carga').

%% escribir_json(+Texto, -Ruta): deja Texto en un archivo temporal.
escribir_json(Texto, Ruta) :-
    tmp_file_stream(text, Ruta, Salida),
    write(Salida, Texto),
    close(Salida).

%% Un archivo valido con dos combinaciones.
json_valido('{"creditosMin":4,"creditosMax":10,"combinaciones":[
  {"creditosTotales":7,"cursos":[
    {"curso":"CE2103","grupo":1,"carrera":"Ing.Computadores","area":"Computadores","creditos":4},
    {"curso":"QU1106","grupo":2,"carrera":"Ing.Computadores","area":"Quimica","creditos":3}]},
  {"creditosTotales":4,"cursos":[
    {"curso":"MA1102","grupo":5,"carrera":"Ing.Computadores","area":"Matematica","creditos":4}]}
]}').

:- begin_tests(politica).

test(porcentaje_propio) :-
    % valor base 100: una combinacion de una sola carrera tiene el 100% de
    % sus creditos en esa carrera (ver el comentario en politica.pl)
    limite_porcentaje('Ing.Computadores', 100).

test(porcentaje_defecto_carrera_desconocida) :-
    max_porcentaje_defecto(D),
    limite_porcentaje('Carrera.Inexistente', D).

test(cursos_area_propio) :-
    limite_cursos_area('Matematica', 2).

test(cursos_area_defecto_area_desconocida) :-
    max_cursos_area_defecto(D),
    limite_cursos_area('AreaNueva', D).

test(limite_es_determinista) :-
    % el resolutor debe dar exactamente una respuesta, sin alternativas
    findall(M, limite_cursos_area('Fisica', M), [_]).

test(porcentajes_en_rango) :-
    forall(max_porcentaje_carrera(_, P), between(0, 100, P)).

test(pares_incompatibles_declarados_una_vez) :-
    % ningun par aparece repetido ni en ambos sentidos: la simetria es de reglas.pl
    findall(A-B, par_incompatible(A, B), Pares),
    forall(member(A-B, Pares), \+ member(B-A, Pares)),
    sort(Pares, Unicos),
    length(Pares, N), length(Unicos, N).

:- end_tests(politica).

:- begin_tests(carga, [setup(limpiar_combinaciones), cleanup(limpiar_combinaciones)]).

test(carga_cuenta_y_forma) :-
    json_valido(Texto), escribir_json(Texto, Ruta),
    cargar_combinaciones(Ruta, Total),
    Total == 2,
    combinacion(1, 7, [curso('CE2103', 1, 'Ing.Computadores', 'Computadores', 4),
                       curso('QU1106', 2, 'Ing.Computadores', 'Quimica', 3)]),
    combinacion(2, 4, [curso('MA1102', 5, 'Ing.Computadores', 'Matematica', 4)]),
    rango_creditos(4, 10).

test(recorrido_por_backtracking) :-
    json_valido(Texto), escribir_json(Texto, Ruta),
    cargar_combinaciones(Ruta),
    findall(Id, combinacion(Id, _, _), Ids),
    Ids == [1, 2].

test(recarga_reemplaza_lo_anterior) :-
    json_valido(Texto), escribir_json(Texto, Ruta1),
    cargar_combinaciones(Ruta1),
    escribir_json('{"creditosMin":1,"creditosMax":2,"combinaciones":[]}', Ruta2),
    cargar_combinaciones(Ruta2, Total),
    Total == 0,
    \+ combinacion(_, _, _),
    rango_creditos(1, 2).

test(archivo_sin_combinaciones_es_valido) :-
    escribir_json('{"creditosMin":6,"creditosMax":14,"combinaciones":[]}', Ruta),
    cargar_combinaciones(Ruta, 0).

test(campo_faltante_lanza_error,
     [throws(error(existence_error(campo_json, area), _))]) :-
    % combinaciones.json de una version anterior, sin "area"
    escribir_json('{"creditosMin":1,"creditosMax":9,"combinaciones":[
      {"creditosTotales":4,"cursos":[
        {"curso":"CE2103","grupo":1,"carrera":"Ing.Computadores","creditos":4}]}]}', Ruta),
    cargar_combinaciones(Ruta).

test(archivo_defectuoso_no_borra_la_carga_anterior) :-
    json_valido(Texto), escribir_json(Texto, Buena),
    cargar_combinaciones(Buena),
    escribir_json('{"creditosMin":1,"creditosMax":9,"combinaciones":[{"cursos":[]}]}', Mala),
    catch(cargar_combinaciones(Mala), error(existence_error(campo_json, _), _), true),
    findall(Id, combinacion(Id, _, _), [1, 2]).

test(tipo_incorrecto_lanza_error, [throws(error(type_error(integer, _), _))]) :-
    escribir_json('{"creditosMin":1,"creditosMax":9,"combinaciones":[
      {"creditosTotales":4,"cursos":[
        {"curso":"CE2103","grupo":"uno","carrera":"Ing.Computadores","area":"Computadores","creditos":4}]}]}', Ruta),
    cargar_combinaciones(Ruta).

test(archivo_inexistente_lanza_error, [throws(error(existence_error(source_sink, _), _))]) :-
    cargar_combinaciones('/ruta/que/no/existe.json').

:- end_tests(carga).
