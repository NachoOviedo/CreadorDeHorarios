%% main.pl: punto de entrada de la etapa 3
%%
%% Ejecucion:
%%   swipl -g main -t halt main.pl
%%   swipl -g main -t halt main.pl Output/combinaciones.json Output/resultado.json

:- use_module(carga).
:- use_module(exportador).

main :-
    current_prolog_flag(argv, Argumentos),
    argumentos(Argumentos, Entrada, Salida),
    catch(
        (
            cargar_combinaciones(Entrada, Cargadas),
            exportar_resultados(Salida, Entrada, Exportadas),
            Cargadas = Exportadas,
            format('Evaluadas ~d combinaciones; resultado en ~w~n',
                   [Exportadas, Salida])
        ),
        Error,
        (print_message(error, Error), halt(1))
    ).

argumentos([], 'Output/combinaciones.json', 'Output/resultado.json').
argumentos([Entrada, Salida], Entrada, Salida) :-
    !.
argumentos([Entrada], Entrada, 'Output/resultado.json') :-
    !.