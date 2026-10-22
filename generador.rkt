#lang typed/racket

(require "tipos.rkt" "jsonUtil.rkt")
(provide cargar-catalogo)
;; generador.rkt convierte el json del catalogo a las structs del proyecto

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
  (json->catalogo (leer-json-archivo ruta)))