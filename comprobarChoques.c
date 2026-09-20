
#include "comprobarChoques.h"

#include <stdio.h>
#include <stddef.h>
#include <string.h>

int bloquesChocan(const Bloque *bloqueA, const Bloque *bloqueB)
{
    //Si falta uno entonces no hay choque
    if (bloqueA == NULL || bloqueB == NULL)
    {
        return 0;
    }

    //Las clases son en dias distintos no hay choque
    if (strcmp(bloqueA->dia, bloqueB->dia))
    {
        return 0;
    };

    //Las clases son el mismo dia falta verificar que sea en el mismo horario
    // Si el inicio de el otro bloque es mayor al final del bloque anterior no chocan

    if ( bloqueA->inicio < bloqueB->fin && bloqueB->inicio < bloqueA->fin)
    {
        return 1;
    }
    return 0;
}

int gruposChocan(const Grupo *grupoA, const Grupo *grupoB)
{
    if (grupoA == NULL || grupoB == NULL)
    {
        return 0;
    };

    //Comprobar si chocan o no los grupos
    for (int i = 0; i < grupoA->cantidadClases; i++)
    {
        for (int j = 0; j < grupoB->cantidadClases; j++)
        {
            if (bloquesChocan(&grupoA->clases[i], &grupoB->clases[j]))
            {
                //Hubo al menos un dia en el que los bloques chocaron
                return 1;
            }
        }
    }
    //No chocaron
    return 0;
}
void detectarChoques(Catalogo *catalogo)
{
    if (catalogo == NULL)
    {
        return;
    }

    for (int c1 = 0; c1 < catalogo->cantidadCursos; c1++)
    {
        Curso *cursoA = &catalogo->cursos[c1];

        for (int g1 = 0; g1 < cursoA->cantidadGrupos; g1++)
        {
            Grupo *grupoA = &cursoA->grupos[g1];

            for (int c2 = c1; c2 < catalogo->cantidadCursos; c2++)
            {
                Curso *cursoB = &catalogo->cursos[c2];
                int g2Inicio = (c2 == c1) ? g1 + 1 : 0;

                for (int g2 = g2Inicio; g2 < cursoB->cantidadGrupos; g2++)
                {
                    Grupo *grupoB = &cursoB->grupos[g2];

                    if (gruposChocan(grupoA, grupoB))
                    {
                        grupoA->choca = 1;
                        grupoB->choca = 1;

                        if (catalogo->cantidadChoques < MAX_CHOQUES)
                        {
                            ParChoque *par = &catalogo->choques[catalogo->cantidadChoques];
                            strncpy(par->codigoCursoA, cursoA->codigo, MAX_LEN_CODIGO);
                            par->numGrupoA = grupoA->numGrupo;
                            strncpy(par->codigoCursoB, cursoB->codigo, MAX_LEN_CODIGO);
                            par->numGrupoB = grupoB->numGrupo;
                            catalogo->cantidadChoques++;
                        }
                    }
                }
            }
        }
    }
}