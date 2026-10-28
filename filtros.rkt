#lang typed/racket

(require "flujo.rkt"
         "tipos.rkt")

(provide filtrar
         filtrar-rango-creditos)

;; Filtro que sirve para streams de cualquier tipo.
(: filtrar (All (A) (-> (-> A Boolean) (Streamof A) (Streamof A))))
(define (filtrar criterio elementos)
  (stream-filter criterio elementos))

;; Conserva los elementos cuyo total de creditos esta entre
;; el minimo y el maximo que eligio el estudiante.
(: filtrar-rango-creditos
   (All (A) (-> (-> A Integer)
                Preferencias
                (Streamof A)
                (Streamof A))))
(define (filtrar-rango-creditos obtener-creditos preferencias elementos)
  (filtrar
   (lambda ([elemento : A])
     (define creditos (obtener-creditos elemento))
     (and (>= creditos (Preferencias-creditos-min preferencias))
          (<= creditos (Preferencias-creditos-max preferencias))))
   elementos))

;; Ejemplo de uso con combinaciones:
;; (filtrar-rango-creditos Combinacion-creditos-totales preferencias stream)