#lang typed/racket

(require "tipos.rkt")
(provide cargar-catalogo)

;; Tipo de los valores que devuelve read-json
(define-type JSExpr (U 'null Boolean String Integer Inexact-Real
                       (Listof JSExpr) (HashTable Symbol JSExpr)))

(require/typed json
  [read-json (->* () (Input-Port) (U JSExpr EOF))])

;; --- Helpers para validar el tipo de cada valor del JSON ---
(: obj (-> JSExpr (HashTable Symbol JSExpr)))
(define (obj j)
  (if (hash? j) j (error 'catalogo "se esperaba un objeto")))

(: lista (-> JSExpr (Listof JSExpr)))
(define (lista j)
  (if (list? j) j (error 'catalogo "se esperaba una lista")))

(: texto (-> JSExpr String))
(define (texto j)
  (if (string? j) j (error 'catalogo "se esperaba un texto")))

(: entero (-> JSExpr Integer))
(define (entero j)
  (if (exact-integer? j) j (error 'catalogo "se esperaba un entero")))

(: campo (-> JSExpr Symbol JSExpr))
(define (campo j clave)
  (hash-ref (obj j) clave
            (lambda () (error 'catalogo "falta el campo '~a'" clave))))

;; --- JSON -> tipos ---
(: json->bloque (-> JSExpr Bloque))
(define (json->bloque j)
  (Bloque (texto (campo j 'dia))
          (entero (campo j 'inicio))
          (entero (campo j 'fin))))

(: json->grupo (-> JSExpr Grupo))
(define (json->grupo j)
  (Grupo (entero (campo j 'numero))
         (texto (campo j 'Profesor))
         (= (entero (campo j 'choca)) 1)
         (map json->bloque (lista (campo j 'clases)))))

(: json->curso (-> JSExpr Curso))
(define (json->curso j)
  (Curso (texto (campo j 'codigo))
         (texto (campo j 'nombre))
         (texto (campo j 'carrera))
         (entero (campo j 'creditos))
         (entero (campo j 'puedeMatricular))
         (map texto (lista (campo j 'requisitos)))
         (map texto (lista (campo j 'correquisitos)))
         (map json->grupo (lista (campo j 'grupos)))))

(: json->choque (-> JSExpr ParChoque))
(define (json->choque j)
  (ParChoque (texto (campo j 'cursoA))
             (entero (campo j 'grupoA))
             (texto (campo j 'cursoB))
             (entero (campo j 'grupoB))))

(: json->catalogo (-> JSExpr Catalogo))
(define (json->catalogo j)
  (Catalogo (map json->curso (lista (campo j 'cursos)))
            (map json->choque (lista (campo j 'choques)))))

;; --- Funcion publica ---
(: cargar-catalogo (-> Path-String Catalogo))
(define (cargar-catalogo ruta)
  (define j (call-with-input-file ruta read-json))
  (if (eof-object? j)
      (error 'catalogo "el archivo esta vacio: ~a" ruta)
      (json->catalogo j)))