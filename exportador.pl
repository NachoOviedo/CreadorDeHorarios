%% exportador.pl: serializa los resultados en JSON para la etapa de Java

:- module(exportador, [
    exportar_resultados/2,
    exportar_resultados/3
]).

:- use_module(library(http/json)).
:- use_module(carga).
:- use_module(razon).

%% Esta función recorre todas las combinaciones cargadas por backtracking 
%% y genera una entrada por cada combinación
exportar_resultados(RutaSalida, Total) :-
    exportar_resultados(RutaSalida, _Entrada, Total).

%% Esta es una variante informativa que conserva la ruta origen en el objeto raíz
exportar_resultados(RutaSalida, RutaEntrada, Total) :-
    findall(Resultado,
            resultado_combinacion(Resultado),
            Resultados),
    length(Resultados, Total),
    Raiz = _{resultados:Resultados,
             entrada:RutaEntrada,
             cantidad:Total},
    setup_call_cleanup(
        open(RutaSalida, write, Stream, [encoding(utf8)]),
        json_write_dict(Stream, Raiz, [width(0)]),
        close(Stream)
    ).

resultado_combinacion(Resultado) :-
    combinacion(Id, Creditos, Cursos),
    pares_curso_grupo(Cursos, Pares),
    veredicto(Cursos, Cumple),
    razon_texto(Cursos, Razon),
    Resultado = _{
        id:Id,
        pares:Pares,
        creditosTotales:Creditos,
        cumple:Cumple,
        razon:Razon
    }.

pares_curso_grupo([], []).
pares_curso_grupo([curso(Codigo, Grupo, _, _, _)|Cursos],
                  [_{curso:CodigoTexto, grupo:Grupo}|Pares]) :-
    atom_string(Codigo, CodigoTexto),
    pares_curso_grupo(Cursos, Pares).
