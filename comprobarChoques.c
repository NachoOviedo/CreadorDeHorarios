
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