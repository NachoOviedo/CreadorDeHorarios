//
// Created by nacho on 9/10/2026.
//
#include <stdio.h>

#include "structCatalogoCursos.h"
#include "parser.h"
#include "constantes.h"

int main(int argc, char *argv[]) {
    const char *ruta = (argc > 1) ? argv[1] : "Horarios/compu.json";

    Catalogo catalogo;
    int resultado = cargarCatalogo(ruta, &catalogo);

    if (resultado != OK) {
        fprintf(stderr, "No se pudo cargar el catalogo (codigo de error %d)\n", resultado);
        return 1;
    }

    printf("Catalogo cargado: %d cursos\n\n", catalogo.cantidadCursos);

    for (int i = 0; i < catalogo.cantidadCursos; i++) {
        Curso *c = &catalogo.cursos[i];
        printf("%-8s %-45s %d creditos, %d grupo(s)\n",
               c->codigo, c->nombre, c->numCreditos, c->cantidadGrupos);

        for (int j = 0; j < c->cantidadGrupos; j++) {
            Grupo *g = &c->grupos[j];
            printf("    grupo %d (%s): ", g->numGrupo, g->profesor);
            for (int k = 0; k < g->cantidadClases; k++) {
                Bloque *b = &g->clases[k];
                printf("%s %d-%d  ", b->dia, b->inicio, b->fin);
            }
            printf("\n");
        }

        if (c->cantidadRequisitos > 0) {
            printf("    requisitos: ");
            for (int r = 0; r < c->cantidadRequisitos; r++) {
                printf("%s%s", c->requisitos[r], (r < c->cantidadRequisitos - 1) ? ", " : "");
            }
            printf("\n");
        }
        printf("\n");
    }

    return 0;
}