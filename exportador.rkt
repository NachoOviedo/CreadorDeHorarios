#lang typed/racket

;; exportador.rkt: escribe las combinaciones validas en un archivo json.
;; Este archivo es el contrato con la etapa de Prolog.

(require "flujo.rkt"
         "tipos.rkt"
         "jsonUtil.rkt")
(provide exportar-combinaciones)

(require/typed json
  [write-json (-> JSExpr Output-Port Void)])

;; Un curso con su grupo elegido, como objeto json
(: seleccion->json (-> Seleccion JSExpr))
(define (seleccion->json s)
  (define curso (Seleccion-curso s))
  (ann (hash 'curso (Curso-codigo curso)
             'grupo (Grupo-numero (Seleccion-grupo s))
             'carrera (Curso-carrera curso)
             'creditos (Curso-creditos curso))
       JSExpr))

;; Una combinacion completa, como objeto json
(: combinacion->json (-> Combinacion JSExpr))
(define (combinacion->json c)
  (ann (hash 'creditosTotales (Combinacion-creditos-totales c)
             'cursos (map seleccion->json (Combinacion-selecciones c)))
       JSExpr))

;; Escribe las combinaciones una por una, separadas por coma.
;; Nunca guarda la lista completa en memoria.
;; Devuelve cuantas combinaciones escribio.
(: escribir-combinaciones (-> (Streamof Combinacion) Output-Port Natural Natural))
(define (escribir-combinaciones resto salida cantidad)
  (if (stream-empty? resto)
      cantidad
      (begin
        (when (> cantidad 0) (write-string "," salida))
        (write-json (combinacion->json (stream-first resto)) salida)
        (escribir-combinaciones (stream-rest resto) salida (add1 cantidad)))))

;; Exporta el stream de combinaciones al archivo. Devuelve el total escrito.
(: exportar-combinaciones
   (-> (Streamof Combinacion) Preferencias Path-String Natural))
(define (exportar-combinaciones combinaciones prefs ruta)
  (call-with-output-file ruta #:exists 'replace
    (lambda ([salida : Output-Port])
      (write-string
       (format "{\"creditosMin\":~a,\"creditosMax\":~a,\"combinaciones\":["
               (Preferencias-creditos-min prefs)
               (Preferencias-creditos-max prefs))
       salida)
      (define total (escribir-combinaciones combinaciones salida 0))
      (write-string "]}" salida)
      total)))
