#lang typed/racket

(require "flujo.rkt"
         "tipos.rkt")

(provide combinaciones-sin-choques)

;; Revisa si una selección es el curso y grupo de un extremo del choque
(: coincide-con-choque? (-> Seleccion String Integer Boolean))
(define (coincide-con-choque? seleccion codigo grupo)
  (and (string=? (Curso-codigo (Seleccion-curso seleccion)) codigo)
       (= (Grupo-numero (Seleccion-grupo seleccion)) grupo)))

;; Compara dos selecciones con los choques que vienen del catálogo
(: hay-choque? (-> Seleccion Seleccion (Listof ParChoque) Boolean))
(define (hay-choque? seleccion otro choques)
  (ormap
   (lambda ([choque : ParChoque])
     (or (and (coincide-con-choque? seleccion
                                     (ParChoque-curso-a choque)
                                     (ParChoque-grupo-a choque))
              (coincide-con-choque? otro
                                     (ParChoque-curso-b choque)
                                     (ParChoque-grupo-b choque)))
         (and (coincide-con-choque? otro
                                     (ParChoque-curso-a choque)
                                     (ParChoque-grupo-a choque))
              (coincide-con-choque? seleccion
                                     (ParChoque-curso-b choque)
                                     (ParChoque-grupo-b choque)))))
   choques))

;; Una opción sirve solo si no choca con ninguna selección anterior
(: compatible? (-> Seleccion (Listof Seleccion)
                    (Listof ParChoque) Boolean))
(define (compatible? opcion elegidos choques)
  (not (ormap (lambda ([elegido : Seleccion])
                (hay-choque? opcion elegido choques))
              elegidos)))

;; Prueba cada grupo de un curso y une los resultados en un stream
(: probar-opciones (-> (Listof Seleccion)
                       (Listof (Listof Seleccion))
                       (Listof Seleccion)
                       (Listof ParChoque)
                       (Streamof (Listof Seleccion))))
(define (probar-opciones opciones restantes elegidos choques)
  (if (null? opciones)
      empty-stream
      (let ([opcion (car opciones)])
        (stream-append
         (if (compatible? opcion elegidos choques)
             (generar-combinaciones restantes
                                    (cons opcion elegidos)
                                    choques)
             empty-stream)
         (probar-opciones (cdr opciones)
                          restantes
                          elegidos
                          choques)))))

;; Elige un grupo por cada curso
;; Si no quedan cursos, devuelve la combinación que se fue armando
(: generar-combinaciones (-> (Listof (Listof Seleccion))
                             (Listof Seleccion)
                             (Listof ParChoque)
                             (Streamof (Listof Seleccion))))
(define (generar-combinaciones opciones elegidos choques)
  (if (null? opciones)
      (stream (reverse elegidos))
      (probar-opciones (car opciones)
                       (cdr opciones)
                       elegidos
                       choques)))

;; Cada lista interna son los grupos posibles para un curso
(: combinaciones-sin-choques
   (-> (Listof (Listof Seleccion))
       (Listof ParChoque)
       (Streamof (Listof Seleccion))))
(define (combinaciones-sin-choques opciones choques)
  (generar-combinaciones opciones '() choques))