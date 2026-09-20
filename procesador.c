#include <stdio.h>
#include <string.h>

#include "structCatalogoCursos.h"
#include "structEstudiante.h"

static const char *buscarCodigoPorNombre(const Catalogo *catalogo, const char *nombre)
{
    int i = 0;
    while (i < catalogo->cantidadCursos)
    {
        if (strcmp(catalogo->cursos[i].nombre, nombre) == 0)
        {
            return catalogo->cursos[i].codigo;
        }
        i++;
    }
    return NULL; // no se encontró como curso en el catálogo
}

void verificarRequisitosCumplidos(Curso *c, const Catalogo *catalogo, const Estudiante *estudiante)
{
    int i = 0;
    while (i < estudiante->cantidadCursosAprobados)
    {
        if (strcmp(estudiante->cursosAprobados[i], c->codigo) == 0)
        {
            c->puedeMatricular = 2; // Ya lo aprobó
            return;
        }
        i++;
    }

    if (c->cantidadRequisitos == 0)
    {
        c->puedeMatricular = 3; // Lo puede llevar por ser de primer semestre, pero hay que verificar correquisitos
        return;
    }

    int count = 0;
    int n = 0;
    while (n < c->cantidadRequisitos)
    {
        const char *codigoRequisito = buscarCodigoPorNombre(catalogo, c->requisitos[n]);
        if (codigoRequisito != NULL)
        {
            i = 0;
            while (i < estudiante->cantidadCursosAprobados)
            {
                if (strcmp(estudiante->cursosAprobados[i], codigoRequisito) == 0)
                {
                    count++;
                    break;
                }
                i++;
            }
        }
        n++;
    }

    if (count == c->cantidadRequisitos) c->puedeMatricular = 3; // Puede llevarlo, pero hay que verificar correquisitos
    else c->puedeMatricular = 0; // No lo puede llevar
}

void verificarCorrequisitos(Curso *curso, Catalogo *catalogo, const Estudiante *estudiante)
{
    if (curso->puedeMatricular != 3) return;
    if (curso->cantidadCorrequisitos == 0)
    {
        curso->puedeMatricular = 1; // Si no tiene correquisitos, lo puede llevar
        return;
    }

    int count = 0;
    int i = 0;
    while (i < curso->cantidadCorrequisitos)
    {
        const char *codigoCorrequisito = buscarCodigoPorNombre(catalogo, curso->correquisitos[i]);
        int n = 0;
        while (codigoCorrequisito != NULL && n < catalogo->cantidadCursos
               && strcmp(codigoCorrequisito, catalogo->cursos[n].codigo) != 0)
        {
            n++;
        }

        if (codigoCorrequisito != NULL && n < catalogo->cantidadCursos && catalogo->cursos[n].puedeMatricular > 0)
        {
            count++;
        }
        i++;
    }

    if (count == curso->cantidadCorrequisitos && curso->puedeMatricular != 2) curso->puedeMatricular = 1;
    else if (curso->puedeMatricular != 2) curso->puedeMatricular = 0;
}

void evaluarElegibilidadCatalogo(Catalogo *catalogo, const Estudiante *estudiante)
{
    int i = 0;
    while (i < catalogo->cantidadCursos)
    {
        verificarRequisitosCumplidos(&catalogo->cursos[i], catalogo, estudiante);
        i++;
    }

    int n = 0;
    while (n < catalogo->cantidadCursos)
    {
        verificarCorrequisitos(&catalogo->cursos[n], catalogo, estudiante);
        n++;
    }
}