#include <stdio.h>

#include "cJSON.h"
#include "constantes.h"
#include "exportador.h"

static cJSON *bloqueAJson(const Bloque *b)
{
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddStringToObject(obj, "dia", b->dia);
    cJSON_AddNumberToObject(obj, "inicio", b->inicio);
    cJSON_AddNumberToObject(obj, "fin", b->fin);
    return obj;
}

static cJSON *grupoAJson(const Grupo *g)
{
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddNumberToObject(obj, "numero", g->numGrupo);
    cJSON_AddStringToObject(obj, "profesor", g->profesor);
    cJSON_AddNumberToObject(obj, "choca", g->choca);

    cJSON *clases = cJSON_CreateArray();
    for (int i = 0; i < g->cantidadClases; i++)
    {
        cJSON_AddItemToArray(clases, bloqueAJson(&g->clases[i]));
    }
    cJSON_AddItemToObject(obj, "clases", clases);

    return obj;
}

static cJSON *arregloStringsAJson(char arreglo[][MAX_LEN_NOMBRE], int cantidad)
{
    cJSON *lista = cJSON_CreateArray();
    for (int i = 0; i < cantidad; i++)
    {
        cJSON_AddItemToArray(lista, cJSON_CreateString(arreglo[i]));
    }
    return lista;
}

static cJSON *cursoAJson(const Curso *c)
{
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddStringToObject(obj, "codigo", c->codigo);
    cJSON_AddStringToObject(obj, "nombre", c->nombre);
    cJSON_AddNumberToObject(obj, "creditos", c->numCreditos);
    cJSON_AddNumberToObject(obj, "puedeMatricular", c->puedeMatricular);

    cJSON_AddItemToObject(obj, "requisitos",
                           arregloStringsAJson((char (*)[MAX_LEN_NOMBRE])c->requisitos, c->cantidadRequisitos));
    cJSON_AddItemToObject(obj, "correquisitos",
                           arregloStringsAJson((char (*)[MAX_LEN_NOMBRE])c->correquisitos, c->cantidadCorrequisitos));

    cJSON *grupos = cJSON_CreateArray();
    for (int i = 0; i < c->cantidadGrupos; i++)
    {
        cJSON_AddItemToArray(grupos, grupoAJson(&c->grupos[i]));
    }
    cJSON_AddItemToObject(obj, "grupos", grupos);

    return obj;
}

static cJSON *choqueAJson(const ParChoque *p)
{
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddStringToObject(obj, "cursoA", p->codigoCursoA);
    cJSON_AddNumberToObject(obj, "grupoA", p->numGrupoA);
    cJSON_AddStringToObject(obj, "cursoB", p->codigoCursoB);
    cJSON_AddNumberToObject(obj, "grupoB", p->numGrupoB);
    return obj;
}

int exportarCatalogo(const Catalogo *catalogo, const char *rutaSalida)
{
    cJSON *raiz = cJSON_CreateObject();

    cJSON *cursos = cJSON_CreateArray();
    for (int i = 0; i < catalogo->cantidadCursos; i++)
    {
        cJSON_AddItemToArray(cursos, cursoAJson(&catalogo->cursos[i]));
    }
    cJSON_AddItemToObject(raiz, "cursos", cursos);

    cJSON *choques = cJSON_CreateArray();
    for (int i = 0; i < catalogo->cantidadChoques; i++)
    {
        cJSON_AddItemToArray(choques, choqueAJson(&catalogo->choques[i]));
    }
    cJSON_AddItemToObject(raiz, "choques", choques);

    char *texto = cJSON_Print(raiz);
    cJSON_Delete(raiz);

    if (texto == NULL)
    {
        return ERROR_JSON_INVALIDO;
    }

    FILE *archivo = fopen(rutaSalida, "w");
    if (archivo == NULL)
    {
        free(texto);
        return ERROR_ARCHIVO_NO_EXISTE;
    }

    fputs(texto, archivo);
    fclose(archivo);
    free(texto);

    return OK;
}