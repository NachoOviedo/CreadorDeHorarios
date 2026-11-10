/* Prueba de obtenerArea(). Compilar y correr (desde la raiz del proyecto):
 *   gcc -I. tests/pruebaArea.c area.c -o pruebaArea && ./pruebaArea
 * o con CMake: el objetivo "pruebaArea".
 * Termina con codigo 0 si todo pasa y 1 si algo falla. */
#include <stdio.h>
#include <string.h>

#include "area.h"
#include "constantes.h"

static int fallos = 0;
static int total = 0;

static void esperar(const char *codigo, const char *esperada)
{
    char area[MAX_LEN_AREA];
    obtenerArea(codigo, area, sizeof(area));
    total++;
    if (strcmp(area, esperada) != 0) {
        fprintf(stderr, "FALLO: '%s' -> '%s' (se esperaba '%s')\n",
                codigo == NULL ? "(NULL)" : codigo, area, esperada);
        fallos++;
    }
}

int main(void)
{
    /* prefijos de los dos planes */
    esperar("CE1101", "Computadores");
    esperar("CE5301", "Computadores");
    esperar("MA1102", "Matematica");
    esperar("FI1101", "Fisica");
    esperar("QU1106", "Quimica");
    esperar("MI3116", "Mantenimiento Industrial");
    esperar("EL2113", "Electronica");
    esperar("AE4208", "Administracion");
    esperar("CS3404", "Ciencias Sociales");
    esperar("CM3207", "Ciencia de Materiales");
    esperar("SE1100", "Actividades Culturales y Deportivas");
    esperar("SO2601", "Seguridad Laboral");

    /* mayusculas y minusculas no importan */
    esperar("ce1101", "Computadores");
    esperar("Ma1102", "Matematica");

    /* prefijo desconocido: el prefijo mismo es el area */
    esperar("ZZ9999", "ZZ");
    esperar("zz9999", "ZZ");

    /* codigos raros */
    esperar("", "SinArea");
    esperar("1234", "SinArea");
    esperar(NULL, "SinArea");
    esperar("CE", "Computadores");   /* sin numeros */

    /* prefijo mas largo que el maximo: se trunca, no se desborda */
    esperar("ABCDEFGH1", "ABCD");

    /* buffer pequeno: nunca se desborda y siempre queda terminado */
    char chico[5];
    obtenerArea("CE1101", chico, sizeof(chico));
    total++;
    if (strcmp(chico, "Comp") != 0) {
        fprintf(stderr, "FALLO: buffer chico dio '%s'\n", chico);
        fallos++;
    }

    printf("%d pruebas, %d fallos\n", total, fallos);
    return fallos == 0 ? 0 : 1;
}
