#lang typed/racket

(require "tipos.rkt")
(provide cargar-catalogo)
;; generador.rkt separa las structs en bloques

;; read-json puede devolver estos valores
;; Los HashTable representan objetos json y las listas representan arreglos
(define-type JSExpr (U 'null Boolean String Integer Inexact-Real
                       (Listof JSExpr) (HashTable Symbol JSExpr)))

(require/typed json
  [read-json (->* () (Input-Port) (U JSExpr EOF))])

;; Estas funciones revisan el tipo de los datos antes de usarlos, son como para verificar errores
(: como-objeto (-> JSExpr (HashTable Symbol JSExpr)))
(define (como-objeto valor)
  (if (hash? valor) valor (error 'catalogo "se esperaba un objeto")))

(: como-lista (-> JSExpr (Listof JSExpr)))
(define (como-lista valor)
  (if (list? valor) valor (error 'catalogo "se esperaba una lista")))

(: como-texto (-> JSExpr String))
(define (como-texto valor)
  (if (string? valor) valor (error 'catalogo "se esperaba un texto")))

(: como-entero (-> JSExpr Integer))
(define (como-entero valor)
  (if (exact-integer? valor)
      valor
      (error 'catalogo "se esperaba un entero")))

;; Busca una clave en un objeto json. Da error si no existe
(: leer-campo (-> JSExpr Symbol JSExpr))
(define (leer-campo valor clave)
  (hash-ref (como-objeto valor) clave
            (lambda () (error 'catálogo "falta el campo '~a'" clave))))

;; Estas funciones convierten cada parte del json a las structs del proyecto
(: json->bloque (-> JSExpr Bloque))
(define (json->bloque j)
  (Bloque (como-texto (leer-campo j 'dia))
          (como-entero (leer-campo j 'inicio))
          (como-entero (leer-campo j 'fin))))

(: json->grupo (-> JSExpr Grupo))
(define (json->grupo j)
  (Grupo (como-entero (leer-campo j 'numero))
         ;; En el JSON de C, este campo empieza con mayúscula.
         (como-texto (leer-campo j 'Profesor))
         (= (como-entero (leer-campo j 'choca)) 1)
         (map json->bloque (como-lista (leer-campo j 'clases)))))

(: json->curso (-> JSExpr Curso))
(define (json->curso j)
  (Curso (como-texto (leer-campo j 'codigo))
         (como-texto (leer-campo j 'nombre))
         (como-texto (leer-campo j 'carrera))
         (como-entero (leer-campo j 'creditos))
         (como-entero (leer-campo j 'puedeMatricular))
         (map como-texto (como-lista (leer-campo j 'requisitos)))
         (map como-texto (como-lista (leer-campo j 'correquisitos)))
         (map json->grupo (como-lista (leer-campo j 'grupos)))))

(: json->choque (-> JSExpr ParChoque))
(define (json->choque j)
  (ParChoque (como-texto (leer-campo j 'cursoA))
             (como-entero (leer-campo j 'grupoA))
             (como-texto (leer-campo j 'cursoB))
             (como-entero (leer-campo j 'grupoB))))

(: json->catalogo (-> JSExpr Catalogo))
(define (json->catalogo j)
  ;; El archivo tiene dos listas principales, cursos y choques
  (Catalogo (map json->curso (como-lista (leer-campo j 'cursos)))
            (map json->choque (como-lista (leer-campo j 'choques)))))

;; Función que usa el resto del programa para cargar el archivo
(: cargar-catalogo (-> Path-String Catalogo))
(define (cargar-catalogo ruta)
  (define j (call-with-input-file ruta read-json))
  (if (eof-object? j)
      (error 'catalogo "el archivo está vacío: ~a" ruta)
      (json->catalogo j)))