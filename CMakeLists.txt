cmake_minimum_required(VERSION 3.15)
project(CreadorDeHorarios C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# constantes.h, parser.h y structCatalogoCursos.h viven en la raiz del proyecto.
# cJSON.h vive en src/.
include_directories(${CMAKE_SOURCE_DIR} ${CMAKE_SOURCE_DIR}/src)

add_executable(CreadorDeHorarios
        mainDePrueba.c
        parser.c
        comprobarChoques.c
        exportador.c
        src/cJSON.c
        procesador.h
        procesador.c
)
