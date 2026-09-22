#include <stdio.h>
#include <string.h>
#include <stddef.h>

#include "structCatalogoCursos.h"
#include "structEstudiante.h"
#include "parser.h"
#include "constantes.h"
#include "comprobarChoques.h"
#include "procesador.h"
#include "exportador.h"

/* Relaciona el valor del campo "carrera" del historial del estudiante
 * con el archivo de catalogo que le corresponde. Agregar una fila aqui
 * por cada carrera nueva que se soporte.
 *
 * IMPORTANTE: el valor de "carrera" debe coincidir EXACTAMENTE (mismas
 * mayusculas, mismos puntos/tildes) con lo que venga en el JSON del
 * historial, porque la comparacion es con strcmp. */
typedef struct {
    const char *carrera;
    const char *rutaCatalogo;
} CarreraCatalogo;

static const CarreraCatalogo CATALOGOS_POR_CARRERA[] = {
    { "Ing.Computadores",  "Horarios/compu.json" },
    { "Ing.Mantenimiento", "Horarios/mante.json" }, /* TODO: confirmar el valor exacto que usara el historial de esta carrera */
};

static const char *rutaCatalogoParaCarrera(const char *carrera)
{
    for (size_t i = 0; i < CANTIDAD_CARRERAS; i++) {
        if (strcmp(carrera, CATALOGOS_POR_CARRERA[i].carrera) == 0) {
            return CATALOGOS_POR_CARRERA[i].rutaCatalogo;
        }
    }
    return NULL; /* carrera desconocida: no hay catalogo configurado para ella */
}

static void imprimirCatalogo(const Catalogo *catalogo) {
    printf("=== Catalogo cargado: %d cursos ===\n\n", catalogo->cantidadCursos);

    for (int i = 0; i < catalogo->cantidadCursos; i++) {
        const Curso *c = &catalogo->cursos[i];
        printf("%-8s %-45s %d creditos, %d grupo(s)\n",
               c->codigo, c->nombre, c->numCreditos, c->cantidadGrupos);

        for (int j = 0; j < c->cantidadGrupos; j++) {
            const Grupo *g = &c->grupos[j];

            if (g->choca) {
                printf("    *** CHOCA ***\n");
            }

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
        printf("    puedeMatricular: %d\n", c->puedeMatricular);
        printf("\n");
    }

    printf("=== Choques detectados: %d ===\n", catalogo->cantidadChoques);
    for (int i = 0; i < catalogo->cantidadChoques; i++) {
        const ParChoque *p = &catalogo->choques[i];
        printf("  %s(grupo %d) <-> %s(grupo %d)\n",
            p->codigoCursoA, p->numGrupoA, p->codigoCursoB, p->numGrupoB);
    }
}

static void imprimirEstudiante(const Estudiante *estudiante) {
    printf("=== Historial cargado ===\n");
    printf("Carnet: %s\n", estudiante->carnet);
    printf("Nombre: %s\n", estudiante->nombre);
    printf("Carrera: %s\n", estudiante->carrera);
    printf("Cursos aprobados (%d): ", estudiante->cantidadCursosAprobados);
    for (int i = 0; i < estudiante->cantidadCursosAprobados; i++) {
        printf("%s%s", estudiante->cursosAprobados[i],
               (i < estudiante->cantidadCursosAprobados - 1) ? ", " : "");
    }
    printf("\n\n");
}

int main(int argc, char *argv[]) {
    const char *rutaHistorial = (argc > 1) ? argv[1] : "Estudiantes/historial_estudiante1.json";

    /* 1. Cargar primero el historial: de ahi sale la carrera, y la
     *    carrera es la que decide que catalogo toca cargar. */
    Estudiante estudiante;
    int resultadoHistorial = cargarHistorialEstudiante(rutaHistorial, &estudiante);
    if (resultadoHistorial != OK) {
        fprintf(stderr, "No se pudo cargar el historial (codigo de error %d)\n", resultadoHistorial);
        return 1;
    }

    /* 2. Elegir el catalogo segun la carrera. argv[2], si se da, permite
     *    forzar un catalogo especifico (util para pruebas) y tiene
     *    prioridad sobre la carrera. */
    const char *rutaCatalogo = (argc > 2) ? argv[2] : rutaCatalogoParaCarrera(estudiante.carrera);
    if (rutaCatalogo == NULL) {
        fprintf(stderr, "Error: no hay catalogo configurado para la carrera '%s'\n",
                estudiante.carrera);
        return 1;
    }

    Catalogo catalogo;
    int resultadoCatalogo = cargarCatalogo(rutaCatalogo, &catalogo);
    if (resultadoCatalogo != OK) {
        fprintf(stderr, "No se pudo cargar el catalogo (codigo de error %d)\n", resultadoCatalogo);
        return 1;
    }

    detectarChoques(&catalogo);
    evaluarElegibilidadCatalogo(&catalogo, &estudiante);

    imprimirCatalogo(&catalogo);
    imprimirEstudiante(&estudiante);

    int resultadoExport = exportarCatalogo(&catalogo, "Output/catalogoExp.json");
    if (resultadoExport != OK) {
        fprintf(stderr, "No se pudo exportar el catalogo (codigo de error %d)\n", resultadoExport);
        return 1;
    }
    printf("Catalogo exportado a Output/catalogoExp.json\n");

    return 0;
}