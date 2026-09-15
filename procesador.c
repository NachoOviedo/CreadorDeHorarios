#include <stdio.h>
#include <string.h>

#include "structCatalogoCursos.h"
#include "structEstudiante.h"

void verificarRequisitosCumplidos(Curso *c, const Estudiante *estudiante)
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
        i = 0;
        while (i < estudiante->cantidadCursosAprobados)
        {
            if (strcmp(estudiante->cursosAprobados[i], c->requisitos[n]) == 0)
            {
                count++;
                break;
            }
            i++;
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
        int n = 0; // Aquí encuentra la posición del correquisito
        while (n < catalogo->cantidadCursos && strcmp(curso->correquisitos[i], catalogo->cursos[n].codigo) != 0)
        {
            n++;
        }

        if (n < catalogo->cantidadCursos && catalogo->cursos[n].puedeMatricular > 0)
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
        verificarRequisitosCumplidos(&catalogo->cursos[i], estudiante);
        i++;
    }

    int n = 0;
    while (n < catalogo->cantidadCursos)
    {
        verificarCorrequisitos(&catalogo->cursos[n], catalogo, estudiante);
        n++;
    }
}