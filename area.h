#ifndef CREADORDEHORARIOS_AREA_H
#define CREADORDEHORARIOS_AREA_H

#include <stddef.h>

/* Calcula el area academica de un curso a partir de su codigo.
 *
 * Criterio: el area es la unidad academica que imparte el curso, y se
 * reconoce por el prefijo de letras del codigo (CE1101 -> "CE" ->
 * "Computadores", MA1102 -> "MA" -> "Matematica").
 *
 * - El prefijo son las letras iniciales del codigo, sin importar
 *   mayusculas o minusculas.
 * - Si el prefijo no esta en la tabla de area.c, el area es el prefijo
 *   en mayusculas, asi un prefijo nuevo funciona como su propia area
 *   sin tener que tocar el codigo.
 * - Si el codigo no empieza con letras (o es NULL), el area es
 *   "SinArea".
 *
 * Escribe el resultado en areaOut (tamano tamOut, siempre terminado en
 * '\0'). Los nombres de area no llevan tildes para que sean faciles de
 * usar como atomos en Prolog y como llaves en Java. */
void obtenerArea(const char *codigoCurso, char *areaOut, size_t tamOut);

#endif //CREADORDEHORARIOS_AREA_H
