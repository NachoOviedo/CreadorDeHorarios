

#ifndef CREADORDEHORARIOS_COMPROVARCHOQUES_H
#define CREADORDEHORARIOS_COMPROVARCHOQUES_H

#include "structCatalogoCursos.h"

int gruposChocan(const Grupo *grupoA, const Grupo *grupoB);
void detectarChoques(Catalogo *catalogo);

#endif //CREADORDEHORARIOS_COMPROBARCHOQUES_H