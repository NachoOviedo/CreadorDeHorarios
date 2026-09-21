#ifndef CREADORDEHORARIOS_PROCESADOR_H
#define CREADORDEHORARIOS_PROCESADOR_H

#include "structEstudiante.h"
#include "structCatalogoCursos.h"

void verificarRequisitosCumplidos(Curso *c, const Catalogo *catalogo, const Estudiante *estudiante);

void evaluarElegibilidadCatalogo(Catalogo *catalogo, const Estudiante *estudiante);


#endif //CREADORDEHORARIOS_PROCESADOR_H