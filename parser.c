#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "constantes.h"
#include "parser.h"


/*----------------------------------------Parser Catalogo-----------------------------------------*/

//funciones provadas

/* Copia segura: siempre deja el string terminado en '\0', nunca se
 * desborda el buffer destino aunque el origen sea más largo. */
static void copiarString(char *destino, size_t tamDestino, const char *origen) {
    if (origen == NULL) {
        destino[0] = '\0';
        return;
    }
    strncpy(destino, origen, tamDestino - 1);
    destino[tamDestino - 1] = '\0';
}

/* Lee un archivo completo a memoria. Quien llama debe hacer free().
 * Retorna NULL si el archivo no se pudo abrir. */
static char *leerArchivoCompleto(const char *ruta) {
    FILE *archivo = fopen(ruta, "rb");
    if (archivo == NULL) {
        return NULL;
    }

    fseek(archivo, 0, SEEK_END);
    long tamanio = ftell(archivo);
    fseek(archivo, 0, SEEK_SET);

    char *buffer = malloc((size_t)tamanio + 1);
    if (buffer == NULL) {
        fclose(archivo);
        return NULL;
    }

    size_t leidos = fread(buffer, 1, (size_t)tamanio, archivo);
    buffer[leidos] = '\0';

    fclose(archivo);
    return buffer;
}

/* Llena un arreglo de strings (para requisitos/correquisitos) a partir
 * de un cJSON array de strings. */
static void llenarArregloStrings(cJSON *arregloJson,
                                  char destino[][MAX_LEN_NOMBRE],
                                  int maxElementos,
                                  int *cantidadOut) {
    int cantidad = 0;

    if (arregloJson != NULL && cJSON_IsArray(arregloJson)) {
        cJSON *elemento = NULL;
        cJSON_ArrayForEach(elemento, arregloJson) {
            if (cantidad >= maxElementos) {
                fprintf(stderr,
                        "Advertencia: se alcanzo el maximo de %d elementos, "
                        "se ignoran los siguientes\n", maxElementos);
                break;
            }
            if (cJSON_IsString(elemento)) {
                copiarString(destino[cantidad], MAX_LEN_NOMBRE, elemento->valuestring);
                cantidad++;
            }
        }
    }

    *cantidadOut = cantidad;
}

/* Llena un BloqueClase a partir de un objeto {"dia", "inicio", "fin"}.
 * Retorna 0 si el bloque quedo incompleto (falta algun campo). */
static int llenarBloque(cJSON *claseJson, Bloque *bloque) {
    cJSON *dia = cJSON_GetObjectItemCaseSensitive(claseJson, "dia");
    cJSON *inicio = cJSON_GetObjectItemCaseSensitive(claseJson, "inicio");
    cJSON *fin = cJSON_GetObjectItemCaseSensitive(claseJson, "fin");

    if (!cJSON_IsString(dia) || !cJSON_IsNumber(inicio) || !cJSON_IsNumber(fin)) {
        return 0;
    }

    copiarString(bloque->dia, MAX_LEN_DIA, dia->valuestring);
    bloque->inicio = (int)inicio->valuedouble;
    bloque->fin = (int)fin->valuedouble;
    return 1;
}

/* Llena un Grupo a partir de un objeto {"numero", "clases", "Profesor"}.
 * Nota: el JSON usa "Profesor" con mayuscula inicial*/

static int llenarGrupo(cJSON *grupoJson, Grupo *grupo) {
    cJSON *numero = cJSON_GetObjectItemCaseSensitive(grupoJson, "numero");
    cJSON *profesor = cJSON_GetObjectItemCaseSensitive(grupoJson, "Profesor");
    cJSON *clases = cJSON_GetObjectItemCaseSensitive(grupoJson, "clases");

    if (!cJSON_IsNumber(numero) || clases == NULL || !cJSON_IsArray(clases)) {
        return 0;
    }

    grupo->numGrupo = (int)numero->valuedouble;
    copiarString(grupo->profesor, MAX_LEN_NOMBRE,
                 cJSON_IsString(profesor) ? profesor->valuestring : "Desconocido");
    grupo->choca = 0; /* se calcula despues, en la fase de deteccion de choques */

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

/* Llena un Curso completo a partir de un objeto del arreglo raiz. */
static int llenarCurso(cJSON *cursoJson, Curso *curso) {
    cJSON *codigo = cJSON_GetObjectItemCaseSensitive(cursoJson, "codigo");
    cJSON *nombre = cJSON_GetObjectItemCaseSensitive(cursoJson, "nombre");
    cJSON *creditos = cJSON_GetObjectItemCaseSensitive(cursoJson, "creditos");
    cJSON *requisitos = cJSON_GetObjectItemCaseSensitive(cursoJson, "requisitos");
    cJSON *correquisitos = cJSON_GetObjectItemCaseSensitive(cursoJson, "correquisitos");
    cJSON *grupos = cJSON_GetObjectItemCaseSensitive(cursoJson, "grupos");

    /* codigo, nombre y creditos son obligatorios: sin ellos el curso
     * no sirve para nada en las fases siguientes. */
    if (!cJSON_IsString(codigo) || !cJSON_IsString(nombre) || !cJSON_IsNumber(creditos)) {
        fprintf(stderr, "Error: curso con campos obligatorios faltantes, se omite\n");
        return 0;
    }

    copiarString(curso->codigo, MAX_LEN_CODIGO, codigo->valuestring);
    copiarString(curso->nombre, MAX_LEN_NOMBRE, nombre->valuestring);
    curso->numCreditos = (int)creditos->valuedouble;

    llenarArregloStrings(requisitos, curso->requisitos, MAX_REQUISITOS,
                          &curso->cantidadRequisitos);
    llenarArregloStrings(correquisitos, curso->correquisitos, MAX_CORREQUISITOS,
                          &curso->cantidadCorrequisitos);

    int cantidadGrupos = 0;
    if (grupos != NULL && cJSON_IsArray(grupos)) {
        cJSON *grupoJson = NULL;
        cJSON_ArrayForEach(grupoJson, grupos) {
            if (cantidadGrupos >= MAX_GRUPOS_POR_CURSO) {
                fprintf(stderr, "Advertencia: %s tiene mas grupos de los soportados\n",
                        curso->codigo);
                break;
            }
            if (llenarGrupo(grupoJson, &curso->grupos[cantidadGrupos])) {
                cantidadGrupos++;
            }
        }
    }
    curso->cantidadGrupos = cantidadGrupos;
    curso->puedeMatricular = 0; /* se calcula en la fase de requisitos */

    return 1;
}

/* ---- funcion publica ---- */
int cargarCatalogo(const char *rutaArchivo, Catalogo *catalogo) {
    char *contenido = leerArchivoCompleto(rutaArchivo);
    if (contenido == NULL) {
        fprintf(stderr, "Error: no se pudo abrir '%s'\n", rutaArchivo);
        return ERROR_ARCHIVO_NO_EXISTE;
    }

    cJSON *raiz = cJSON_Parse(contenido);
    free(contenido); /* ya no se necesita el texto crudo, cJSON hizo su propia copia */

    if (raiz == NULL) {
        const char *errorPtr = cJSON_GetErrorPtr();
        fprintf(stderr, "Error: JSON invalido cerca de: %s\n",
                errorPtr != NULL ? errorPtr : "(desconocido)");
        return ERROR_JSON_INVALIDO;
    }

    if (!cJSON_IsArray(raiz)) {
        fprintf(stderr, "Error: se esperaba un arreglo de cursos en la raiz del JSON\n");
        cJSON_Delete(raiz);
        return ERROR_JSON_INVALIDO;
    }

    int cantidadCursos = 0;
    cJSON *cursoJson = NULL;
    cJSON_ArrayForEach(cursoJson, raiz) {
        if (cantidadCursos >= MAX_CURSOS) {
            fprintf(stderr, "Advertencia: se alcanzo MAX_CURSOS (%d), se ignoran el resto\n",
                    MAX_CURSOS);
            break;
        }
        if (llenarCurso(cursoJson, &catalogo->cursos[cantidadCursos])) {
            cantidadCursos++;
        }
    }
    catalogo->cantidadCursos = cantidadCursos;

    cJSON_Delete(raiz);
    return OK;
}

/*----------------------------------------Parser Estudiante-----------------------------------------*/

//Funcion privada
static void escritorDeCodigos(cJSON *arregloJson,
                               char destino[][MAX_LEN_CODIGO],
                               int maxElementos,
                               int *cantidadOut) {
    int cantidad = 0;

    if (arregloJson != NULL && cJSON_IsArray(arregloJson)) {
        cJSON *elemento = NULL;
        cJSON_ArrayForEach(elemento, arregloJson) {
            if (cantidad >= maxElementos) {
                fprintf(stderr, "Advertencia: se alcanzo el maximo de %d elementos\n", maxElementos);
                break;
            }
            if (cJSON_IsString(elemento)) {
                copiarString(destino[cantidad],MAX_LEN_CODIGO, elemento->valuestring);
                cantidad++;
            }
        }
    }

    *cantidadOut = cantidad;
}

int llenarEstudiante(cJSON *estudianteJson, Estudiante *estudiante) {
    cJSON *carnet = cJSON_GetObjectItemCaseSensitive(estudianteJson, "carnet");
    cJSON *nombre = cJSON_GetObjectItemCaseSensitive(estudianteJson, "nombre");
    cJSON *cursosAprobados = cJSON_GetObjectItemCaseSensitive(estudianteJson, "cursosAprobados");

    if (!cJSON_IsString(carnet) || !cJSON_IsString(nombre)) {
        fprintf(stderr, "Error: historial con campos obligatorios faltantes\n");
        return 0;
    }

    copiarString(estudiante->carnet, MAX_LEN_CARNET, carnet->valuestring);
    copiarString(estudiante->nombre, MAX_LEN_NOMBRE, nombre->valuestring);
    escritorDeCodigos(cursosAprobados, estudiante->cursosAprobados, MAX_CURSOS_APROBADOS,
                       &estudiante->cantidadCursosAprobados);

    return 1;
}

//funcion publica

int cargarHistorialEstudiante(const char *rutaArchivo, Estudiante *estudiante)
{
    char *contenido = leerArchivoCompleto(rutaArchivo);
    if (contenido == NULL) {
        fprintf(stderr, "Error: no se pudo abrir '%s'\n", rutaArchivo);
        return ERROR_ARCHIVO_NO_EXISTE;
    }

    cJSON *raiz = cJSON_Parse(contenido);
    free(contenido); /* ya no se necesita el texto crudo, cJSON hizo su propia copia */

    if (raiz == NULL) {
        const char *errorPtr = cJSON_GetErrorPtr();
        fprintf(stderr, "Error: JSON invalido cerca de: %s\n",
                errorPtr != NULL ? errorPtr : "(desconocido)");
        return ERROR_JSON_INVALIDO;
    }

    int exito = llenarEstudiante(raiz, estudiante);

    cJSON_Delete(raiz);

    if (exito) return OK;

    return ERROR_CAMPO_FALTANTE;
};