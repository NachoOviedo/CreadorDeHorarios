#lang typed/racket

;; Pruebas del programa. Se corren con: raco test tests/pruebas.rkt
;; Usan un catalogo pequeno armado a mano, asi no dependen de ningun archivo.

(require typed/rackunit
         "../flujo.rkt"
         "../tipos.rkt"
         "../main.rkt"
         "../filtros.rkt"
         "../exportador.rkt"
         "../jsonUtil.rkt")

;; --- Datos de prueba ---

;; CA grupo 1 choca con CB grupo 1 (los dos son los lunes por la manana)
(define ca (Curso "CA" "Curso A" "Ing.Computadores" 3 1 '() '()
                  (list (Grupo 1 "Prof 1" #t (list (Bloque "lunes" 730 920)))
                        (Grupo 2 "Prof 2" #f (list (Bloque "martes" 730 920))))))
(define cb (Curso "CB" "Curso B" "Ing.Computadores" 4 1 '() '()
                  (list (Grupo 1 "Prof 3" #t (list (Bloque "lunes" 800 950)))
                        (Grupo 2 "Prof 4" #f (list (Bloque "miercoles" 730 920))))))
;; CC no se puede matricular (puede-matricular = 0)
(define cc (Curso "CC" "Curso C" "Ing.Computadores" 2 0 '() '()
                  (list (Grupo 1 "Prof 5" #f (list (Bloque "jueves" 730 920))))))

(define catalogo
  (Catalogo (list ca cb cc)
            (list (ParChoque "CA" 1 "CB" 1))))

(define (prefs [minimo : Integer] [maximo : Integer]) : Preferencias
  (Preferencias (list (Interes "CA" '()) (Interes "CB" '()) (Interes "CC" '()))
                minimo
                maximo))

;; Junta los pares curso-grupo de una combinacion, para compararlos facil
(: pares (-> Combinacion (Listof (Pairof String Integer))))
(define (pares c)
  (map (lambda ([s : Seleccion])
         (cons (Curso-codigo (Seleccion-curso s))
               (Grupo-numero (Seleccion-grupo s))))
       (Combinacion-selecciones c)))

;; --- Pruebas ---

(test-case "subconjuntos genera 2^n subconjuntos"
  (check-equal? (length (stream->list (subconjuntos '(1 2 3)))) 8)
  (check-equal? (length (stream->list (subconjuntos '()))) 1))

(test-case "subconjuntos es perezoso: no recorre los 2^40 subconjuntos"
  (check-equal? (stream-first (subconjuntos (range 40))) (range 40)))

(test-case "subconjuntos sirve para cualquier tipo"
  (check-equal? (length (stream->list (subconjuntos '("a" "b")))) 4))

(test-case "armar-opciones omite los cursos que no se pueden matricular"
  (check-equal? (length (armar-opciones catalogo (prefs 1 20))) 2)
  (check-equal? (cursos-omitidos catalogo (prefs 1 20)) '("CC")))

(test-case "armar-opciones respeta los grupos pedidos"
  (define solo-grupo-2 (Preferencias (list (Interes "CA" '(2))) 1 20))
  (define opciones (armar-opciones catalogo solo-grupo-2))
  (check-equal? (length opciones) 1)
  (check-equal? (length (car opciones)) 1)
  (check-equal? (Grupo-numero (Seleccion-grupo (car (car opciones)))) 2))

(test-case "armar-combinacion suma los creditos"
  (define c (armar-combinacion
             (list (Seleccion ca (car (Curso-grupos ca)))
                   (Seleccion cb (car (Curso-grupos cb))))))
  (check-equal? (Combinacion-creditos-totales c) 7))

(test-case "generar no incluye combinaciones con choques"
  (define todas (stream->list (generar catalogo (prefs 1 20))))
  ;; CA solo: 2, CB solo: 2, CA y CB: 4 menos el choque = 3
  (check-equal? (length todas) 7)
  (check-false (member (list (cons "CA" 1) (cons "CB" 1))
                       (map pares todas))))

(test-case "generar filtra por el rango de creditos"
  (define solo-las-dos (stream->list (generar catalogo (prefs 5 7))))
  (check-equal? (length solo-las-dos) 3)
  (check-true (andmap (lambda ([c : Combinacion])
                        (= (Combinacion-creditos-totales c) 7))
                      solo-las-dos))
  (check-equal? (length (stream->list (generar catalogo (prefs 3 3)))) 2)
  (check-equal? (length (stream->list (generar catalogo (prefs 50 60)))) 0))

(test-case "filtrar-rango-creditos funciona con cualquier tipo"
  (check-equal?
   (stream->list
    (filtrar-rango-creditos (lambda ([n : Integer]) n)
                            (Preferencias '() 3 5)
                            (stream 1 3 4 5 6)))
   '(3 4 5))
  (check-equal?
   (stream->list
    (filtrar-rango-creditos (lambda ([s : String]) (string-length s))
                            (Preferencias '() 2 3)
                            (stream "a" "ab" "abc" "abcd")))
   '("ab" "abc")))

(test-case "exportar-combinaciones escribe el json con los campos pedidos"
  (define ruta (make-temporary-file "combinaciones~a.json"))
  (define total
    (exportar-combinaciones (generar catalogo (prefs 5 7)) (prefs 5 7) ruta))
  (check-equal? total 3)
  (define raiz (leer-json-archivo ruta))
  (check-equal? (como-entero (leer-campo raiz 'creditosMin)) 5)
  (check-equal? (como-entero (leer-campo raiz 'creditosMax)) 7)
  (define combinaciones (como-lista (leer-campo raiz 'combinaciones)))
  (check-equal? (length combinaciones) 3)
  (define primera (car combinaciones))
  (check-equal? (como-entero (leer-campo primera 'creditosTotales)) 7)
  (define cursos (como-lista (leer-campo primera 'cursos)))
  (check-equal? (length cursos) 2)
  (check-equal? (como-texto (leer-campo (car cursos) 'carrera)) "Ing.Computadores")
  (check-true (exact-integer? (leer-campo (car cursos) 'grupo)))
  (delete-file ruta))

(test-case "exportar-combinaciones con cero combinaciones escribe una lista vacia"
  (define ruta (make-temporary-file "combinaciones~a.json"))
  (check-equal? (exportar-combinaciones (generar catalogo (prefs 50 60))
                                        (prefs 50 60)
                                        ruta)
                0)
  (check-equal? (como-lista (leer-campo (leer-json-archivo ruta) 'combinaciones))
                '())
  (delete-file ruta))
