#lang typed/racket

(require "tipos.rkt" "jsonUtil.rkt")
(provide cargarPreferencias validarPreferencias)

;Lectura del jason con preferencias

(: json->interes (-> JSExpr Interes ))
(define (json->interes j)
  (Interes (como-texto (leer-campo j 'curso))
          (map como-entero (como-lista (leer-campo j 'grupos)))))

(: json->preferencias (-> JSExpr Preferencias))
(define (json->preferencias j)
  (Preferencias (map json->interes (como-lista (leer-campo j 'intereses)))
                (como-entero (leer-campo j 'creditosMin))
                (como-entero (leer-campo j 'creditosMax))))

;; Funcion para cargar el archivo
(: cargarPreferencias (-> Path-String Preferencias))
(define (cargarPreferencias ruta)
  (json->preferencias (leer-json-archivo ruta)))

;; Validacion con el catalogo

(: buscar-curso (-> String (Listof Curso) (U Curso #f)))
(define (buscar-curso codigo cursos)
  (findf (lambda ([c : Curso]) (string=? (Curso-codigo c) codigo))
         cursos))

(: validar-interes (-> Interes Catalogo Void))
(define (validar-interes interes catalogo)
  (define codigo (Interes-codigo interes))
  (define curso (buscar-curso codigo (Catalogo-cursos catalogo)))
  (unless curso
    (error 'preferencias "el curso ~a no existe en el catalogo" codigo))
  (define numeros (map Grupo-numero (Curso-grupos curso)))
  (for ([g (in-list (Interes-grupos interes))])
    (unless (member g numeros)
      (error 'preferencias "el curso ~a no tiene el grupo ~a" codigo g))))

;; valida las preferencias del estudiante
;; (validarPreferencias (cargarPreferencias "preferencias.json") catalogo)
(: validarPreferencias (-> Preferencias Catalogo Preferencias))
(define (validarPreferencias prefs catalogo)
  (define cmin (Preferencias-creditos-min prefs))
  (define cmax (Preferencias-creditos-max prefs))
  (unless (and (> cmin 0) (<= cmin cmax))
    (error 'preferencias
           "creditos invalidos: el minimo (~a) debe ser positivo y no mayor al maximo (~a)"
           cmin cmax))
  (for ([i (in-list (Preferencias-intereses prefs))])
    (validar-interes i catalogo))
  prefs)