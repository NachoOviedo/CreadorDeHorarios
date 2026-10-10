
#ifndef CREADORDEHORARIOS_PARSER_H
#define CREADORDEHORARIOS_PARSER_H

#include "structCatalogoCursos.h"
#include "structEstudiante.h"

int cargarCatalogo(const char *ruta, const char *carrera, Catalogo *catalogo);

int cargarHistorialEstudiante(const char *rutaArchivo, Estudiante *estudiante);

#endif //CREADORDEHORARIOS_PARSER_H