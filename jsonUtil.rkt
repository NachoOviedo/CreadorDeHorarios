#lang typed/racket

;; json-util.rkt: helpers compartidos para leer JSON con tipos seguros
(provide (all-defined-out))

;; read-json puede devolver estos valores
;; Los HashTable representan objetos json y las listas representan arreglos
(define-type JSExpr (U 'null Boolean String Integer Inexact-Real
                       (Listof JSExpr) (HashTable Symbol JSExpr)))

(require/typed json
  [read-json (->* () (Input-Port) (U JSExpr EOF))])

;; Estas funciones revisan el tipo de los datos antes de usarlos
(: como-objeto (-> JSExpr (HashTable Symbol JSExpr)))
(define (como-objeto valor)
  (if (hash? valor) valor (error 'json "se esperaba un objeto")))

(: como-lista (-> JSExpr (Listof JSExpr)))
(define (como-lista valor)
  (if (list? valor) valor (error 'json "se esperaba una lista")))

(: como-texto (-> JSExpr String))
(define (como-texto valor)
  (if (string? valor) valor (error 'json "se esperaba un texto")))

(: como-entero (-> JSExpr Integer))
(define (como-entero valor)
  (if (exact-integer? valor)
      valor
      (error 'json "se esperaba un entero")))

;; Busca una clave en un objeto json. Da error si no existe
(: leer-campo (-> JSExpr Symbol JSExpr))
(define (leer-campo valor clave)
  (hash-ref (como-objeto valor) clave
            (lambda () (error 'json "falta el campo '~a'" clave))))

;; Abre un archivo y devuelve su contenido json. Da error si esta vacio
(: leer-json-archivo (-> Path-String JSExpr))
(define (leer-json-archivo ruta)
  (define j (call-with-input-file ruta read-json))
  (if (eof-object? j)
      (error 'json "el archivo esta vacio: ~a" ruta)
      j))