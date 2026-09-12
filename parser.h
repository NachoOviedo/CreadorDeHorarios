//
// Created by nacho on 9/10/2026.
//

#ifndef CREADORDEHORARIOS_PARSER_H
#define CREADORDEHORARIOS_PARSER_H

#include "structCatalogoCursos.h"
#include "structEstudiante.h"

int cargarCatalogo( const char *ruta, Catalogo *catalgo);

int cargarHistorialEstudiante(const char *rutaArchivo, Estudiante *estudiante);

#endif //CREADORDEHORARIOS_PARSER_H