#include <stdio.h>

#include "structCatalogoCursos.h"
#include "structEstudiante.h"
#include "parser.h"
#include "constantes.h"
#include "exportador.h"

static void imprimirCatalogo(const Catalogo *catalogo) {
    printf("=== Catalogo cargado: %d cursos ===\n\n", catalogo->cantidadCursos);

    for (int i = 0; i < catalogo->cantidadCursos; i++) {
        const Curso *c = &catalogo->cursos[i];
        printf("%-8s %-45s %d creditos, %d grupo(s)\n",
               c->codigo, c->nombre, c->numCreditos, c->cantidadGrupos);

        for (int j = 0; j < c->cantidadGrupos; j++) {
            const Grupo *g = &c->grupos[j];
            printf("    grupo %d (%s): ", g->numGrupo, g->profesor);
            for (int k = 0; k < g->cantidadClases; k++) {
                const Bloque *b = &g->clases[k];
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
}

static void imprimirEstudiante(const Estudiante *estudiante) {
    printf("=== Historial cargado ===\n");
    printf("Carnet: %s\n", estudiante->carnet);
    printf("Nombre: %s\n", estudiante->nombre);
    printf("Cursos aprobados (%d): ", estudiante->cantidadCursosAprobados);
    for (int i = 0; i < estudiante->cantidadCursosAprobados; i++) {
        printf("%s%s", estudiante->cursosAprobados[i],
               (i < estudiante->cantidadCursosAprobados - 1) ? ", " : "");
    }
    printf("\n\n");
}

int main(int argc, char *argv[]) {
    const char *rutaCatalogo = (argc > 1) ? argv[1] : "Horarios/compu.json";
    const char *rutaHistorial = (argc > 2) ? argv[2] : "Estudiantes/historial_estudiante.json";

    Catalogo catalogo;
    int resultadoCatalogo = cargarCatalogo(rutaCatalogo, &catalogo);
    if (resultadoCatalogo != OK) {
        fprintf(stderr, "No se pudo cargar el catalogo (codigo de error %d)\n", resultadoCatalogo);
        return 1;
    }
    imprimirCatalogo(&catalogo);

    Estudiante estudiante;
    int resultadoHistorial = cargarHistorialEstudiante(rutaHistorial, &estudiante);
    if (resultadoHistorial != OK) {
        fprintf(stderr, "No se pudo cargar el historial (codigo de error %d)\n", resultadoHistorial);
        return 1;
    }
    imprimirEstudiante(&estudiante);

    int resultadoExport = exportarCatalogo(&catalogo, "Output/catalogoExp.json");
    if (resultadoExport != OK) {
        fprintf(stderr, "No se pudo exportar el catalogo (codigo de error %d)\n", resultadoExport);
        return 1;
    }
    printf("Catalogo exportado a Output/catalogoExp.json\n");

    return 0;
}
