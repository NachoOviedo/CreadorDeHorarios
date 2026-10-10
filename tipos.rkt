#lang typed/racket

(provide (all-defined-out))

;; Un tramo de horario (dia, hora de inicio y fin, ej. 730 = 7:30)
(struct Bloque ([dia : String]
                [inicio : Integer]
                [fin : Integer])
  #:transparent)

;; Un grupo de un curso, con su horario
(struct Grupo ([numero : Integer]
               [profesor : String]
               [choca : Boolean]
               [clases : (Listof Bloque)])
  #:transparent)

;; Un curso del catalogo
(struct Curso ([codigo : String]
               [nombre : String]
               [carrera : String]
               [creditos : Integer]
               [puede-matricular : Integer]
               [requisitos : (Listof String)]
               [correquisitos : (Listof String)]
               [grupos : (Listof Grupo)])
  #:transparent)

;; Un par de grupos que chocan entre si
(struct ParChoque ([curso-a : String]
                   [grupo-a : Integer]
                   [curso-b : String]
                   [grupo-b : Integer])
  #:transparent)

;; El catalogo completo que exporta C
(struct Catalogo ([cursos : (Listof Curso)]
                  [choques : (Listof ParChoque)])
  #:transparent)