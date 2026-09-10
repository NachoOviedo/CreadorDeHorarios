#ifndef CREADORDEHORARIOS_CURSOS_H
#define CREADORDEHORARIOS_CURSOS_H

#include "constantes.h"

typedef struct
{
    char dia[MAX_LEN_DIA];
    int inicio;
    int fin;
} Bloque;

typedef struct
{
    int numGrupo;
    char profesor[MAX_LEN_PROFESOR];
    Bloque clases[MAX_CLASES_POR_GRUPO];
    int cantidadClases;
    int choca;
} Grupo;

typedef struct
{
    char codigo[MAX_LEN_CODIGO];
    char nombre[MAX_LEN_NOMBRE];
    int numCreditos;
    char requisitos[MAX_REQUISITOS][MAX_LEN_NOMBRE];
    int cantidadRequisitos;
    char correquisitos[MAX_CORREQUISITOS][MAX_LEN_NOMBRE];
    int cantidadCorrequisitos;
    Grupo grupos[MAX_GRUPOS_POR_CURSO];
    int cantidadGrupos;
    int puedeMatricular;
} Curso;

typedef struct
{
    Curso cursos[MAX_CURSOS];
    int cantidadCursos;
} Catalogo;

#endif //CREADORDEHORARIOS_CURSOS_H