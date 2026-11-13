#include <ctype.h>
#include <string.h>

#include "area.h"
#include "constantes.h"

#define MAX_LEN_PREFIJO 4

typedef struct {
    const char *prefijo;
    const char *area;
} AreaPorPrefijo;

/* Un prefijo por fila. Para soportar una unidad academica nueva basta
 * con agregar una fila aqui. El nombre debe ser corto, sin tildes y sin
 * depender de mayusculas para distinguirse de otras areas. */
static const AreaPorPrefijo AREAS[] = {
    { "AE", "Administracion" },
    { "CA", "Computacion" },
    { "CE", "Computadores" },
    { "CI", "Idiomas y Comunicacion" },
    { "CM", "Ciencia de Materiales" },
    { "CS", "Ciencias Sociales" },
    { "EL", "Electronica" },
    { "FI", "Fisica" },
    { "MA", "Matematica" },
    { "ME", "Tecnologia de Materiales" },
    { "MI", "Mantenimiento Industrial" },
    { "PI", "Produccion Industrial" },
    { "QU", "Quimica" },
    { "SE", "Actividades Culturales y Deportivas" },
    { "SO", "Seguridad Laboral" },
};

static const size_t CANTIDAD_AREAS = sizeof(AREAS) / sizeof(AREAS[0]);

/* Copia segura: nunca desborda el destino y siempre lo termina en '\0'. */
static void copiarSeguro(char *destino, size_t tamDestino, const char *origen)
{
    if (destino == NULL || tamDestino == 0) {
        return;
    }
    strncpy(destino, origen, tamDestino - 1);
    destino[tamDestino - 1] = '\0';
}

void obtenerArea(const char *codigoCurso, char *areaOut, size_t tamOut)
{
    if (areaOut == NULL || tamOut == 0) {
        return;
    }

    /* 1. Extraer el prefijo: las letras iniciales, en mayusculas. */
    char prefijo[MAX_LEN_PREFIJO + 1];
    size_t largo = 0;

    if (codigoCurso != NULL) {
        while (isalpha((unsigned char)codigoCurso[largo])) {
            if (largo < MAX_LEN_PREFIJO) {
                prefijo[largo] = (char)toupper((unsigned char)codigoCurso[largo]);
            }
            largo++;
        }
    }

    if (largo == 0) {
        copiarSeguro(areaOut, tamOut, "SinArea");
        return;
    }
    if (largo > MAX_LEN_PREFIJO) {
        largo = MAX_LEN_PREFIJO;
    }
    prefijo[largo] = '\0';

    /* 2. Buscar el prefijo en la tabla. */
    for (size_t i = 0; i < CANTIDAD_AREAS; i++) {
        if (strcmp(prefijo, AREAS[i].prefijo) == 0) {
            copiarSeguro(areaOut, tamOut, AREAS[i].area);
            return;
        }
    }

    /* 3. Prefijo desconocido: el propio prefijo funciona como area. */
    copiarSeguro(areaOut, tamOut, prefijo);
}
