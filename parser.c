//
// Created by nacho on 9/10/2026.
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "parser.h"
#include "constantes.h"

static void copiarString(char *destino, size_t tamDestino, const char *origen) {
    if (origen == NULL) {
        destino[0] = '\0';
        return;
    }
    /* -1 espacio extra para el caracter de finalizacion de string*/
    strncpy(destino, origen, tamDestino - 1);
    destino[tamDestino - 1] = '\0';
}

static char *leerArchivoCompleto(const char *ruta)
{
    FILE *archivo = fopen(ruta, "rb" );
    if (archivo == NULL) {
        return NULL;
    }

    fseek(archivo, 0, SEEK_END);
    long tamanio = ftell(archivo);
    rewind(archivo); /*Vuelve al inicio del archivo */

    char *buffer = malloc((size_t) tamanio + 1); /* +1 se agrega para el caracter del final de los strings u kno*/
    if (buffer == NULL) {
        fclose(archivo);
        return NULL;
    }

    size_t leidos = fread(buffer, 1, (size_t) tamanio, archivo);
    buffer[leidos] = '\0';

    fclose(archivo);
    return buffer;
}

static int llenarBloque(cJSON *claseJson, Bloque *bloque) {
    cJSON *dia = cJSON_GetObjectItemCaseSensitive(claseJson, "dia");
    cJSON *inicio = cJSON_GetObjectItemCaseSensitive(claseJson, "inicio");
    cJSON *fin = cJSON_GetObjectItemCaseSensitive(claseJson, "fin");

    if (!cJSON_IsString(dia) || !cJSON_IsNumber(inicio) || !cJSON_IsNumber(fin)) {
        return 0;
    }

    copiarString(bloque->dia, MAX_LEN_DIA, dia->valuestring);
    /*             casteo  puntero(ingreso y busco value de tipo double)*/
    bloque->inicio = (int)inicio->valuedouble;
    bloque->fin = (int)fin->valuedouble;

    return 1;
}

static int llenarGrupo(cJSON *grupoJson, Grupo *grupo) {
    cJSON *numero = cJSON_GetObjectItemCaseSensitive(grupoJson, "numero");
    cJSON *profesor = cJSON_GetObjectItemCaseSensitive(grupoJson, "Profesor");
    cJSON *clases = cJSON_GetObjectItemCaseSensitive(grupoJson, "clases");

    if (!cJSON_IsNumber(numero) || clases == NULL || !cJSON_IsArray(clases)) {
        return 0;
    }

    grupo->numGrupo = (int) numero->valuedouble;
    if (cJSON_IsString(profesor)) {
        copiarString(grupo->profesor, MAX_LEN_PROFESOR, profesor->valuestring);
    } else {
        copiarString(grupo->profesor, MAX_LEN_PROFESOR, "Sin asignar");
    }
    grupo->choca = 0;

    int cantidadClases = 0;
    cJSON *claseJson = NULL;
    cJSON_ArrayForEach(claseJson, clases) {
        if (cantidadClases >= MAX_CLASES_POR_GRUPO) {
            fprintf(stderr, "Advertencia: grupo %d tiene mas bloques de los soportados\n",
                    grupo->numGrupo);
            break;
        }
        if (llenarBloque(claseJson, &grupo->clases[cantidadClases])) {
            cantidadClases++;
        }
    }
    grupo->cantidadClases = cantidadClases;

    return 1;
}