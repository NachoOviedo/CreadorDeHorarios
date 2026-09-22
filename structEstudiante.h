
#ifndef CREADORDEHORARIOS_STRUCTESTUDIANTE_H
#define CREADORDEHORARIOS_STRUCTESTUDIANTE_H

#include "constantes.h"

typedef struct {
    char carnet[MAX_LEN_CARNET];
    char nombre[MAX_LEN_NOMBRE];
    char carrera[MAX_LEN_NOMBRE];
    char cursosAprobados[MAX_CURSOS_APROBADOS][MAX_LEN_CODIGO];
    int  cantidadCursosAprobados;
} Estudiante;

#endif //CREADORDEHORARIOS_STRUCTESTUDIANTE_H