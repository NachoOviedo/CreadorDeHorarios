#lang typed/racket

(require "tipos.rkt" "jsonUtil.rkt")
(provide cargarPreferencias validarPreferencias)

;; Lectura del json con preferencias

(: json->interes (-> JSExpr Interes))
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

;; Busca un curso por codigo de forma recursiva.
;; Caso base: lista vacia -> no existe (#f).
;; Si el primero coincide, lo devuelve; si no, sigue con el resto.
(: buscar-curso (-> String (Listof Curso) (U Curso #f)))
(define (buscar-curso codigo cursos)
  (cond
    [(null? cursos) #f]
    [(string=? (Curso-codigo (car cursos)) codigo) (car cursos)]
    [else (buscar-curso codigo (cdr cursos))]))

;; Revisa recursivamente que cada grupo pedido exista en el curso.
;; Caso base: no quedan grupos por revisar.
(: validar-grupos (-> String (Listof Integer) (Listof Integer) Void))
(define (validar-grupos codigo pedidos existentes)
  (if (null? pedidos)
      (void)
      (begin
        (unless (member (car pedidos) existentes)
          (error 'preferencias "el curso ~a no tiene el grupo ~a"
                 codigo (car pedidos)))
        (validar-grupos codigo (cdr pedidos) existentes))))

(: validar-interes (-> Interes Catalogo Void))
(define (validar-interes interes catalogo)
  (define codigo (Interes-codigo interes))
  (define curso (buscar-curso codigo (Catalogo-cursos catalogo)))
  (unless curso
    (error 'preferencias "el curso ~a no existe en el catalogo" codigo))
  (validar-grupos codigo
                  (Interes-grupos interes)
                  (map Grupo-numero (Curso-grupos curso))))

;; Valida recursivamente cada interes de la lista.
;; Caso base: no quedan intereses por validar.
(: validar-intereses (-> (Listof Interes) Catalogo Void))
(define (validar-intereses intereses catalogo)
  (if (null? intereses)
      (void)
      (begin
        (validar-interes (car intereses) catalogo)
        (validar-intereses (cdr intereses) catalogo))))

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
  (validar-intereses (Preferencias-intereses prefs) catalogo)
  prefs)