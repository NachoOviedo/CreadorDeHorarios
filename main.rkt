#lang typed/racket

;; main.rkt: une todas las partes del programa.
;; Lee el catalogo que exporta C y las preferencias del estudiante,
;; genera las combinaciones sin choques, las filtra por creditos
;; y las exporta a un archivo json.

(require "flujo.rkt"
         "tipos.rkt"
         "generador.rkt"
         "preferencias.rkt"
         "combinaciones.rkt"
         "filtros.rkt"
         "exportador.rkt")

(provide subconjuntos
         armar-opciones
         cursos-omitidos
         armar-combinacion
         generar
         ejecutar)

;; --- Paso 1: convertir las preferencias en opciones por curso ---

(: curso-por-codigo (-> String Catalogo (U Curso #f)))
(define (curso-por-codigo codigo catalogo)
  (findf (lambda ([c : Curso]) (string=? (Curso-codigo c) codigo))
         (Catalogo-cursos catalogo)))

;; Segun C, 1 significa que el estudiante puede matricular el curso
(: habilitado? (-> Curso Boolean))
(define (habilitado? curso)
  (= (Curso-puede-matricular curso) 1))

;; Grupos que acepta el estudiante. Si no indico ninguno, acepta todos
(: grupos-aceptados (-> Curso Interes (Listof Grupo)))
(define (grupos-aceptados curso interes)
  (define pedidos (Interes-grupos interes))
  (if (null? pedidos)
      (Curso-grupos curso)
      (filter (lambda ([g : Grupo]) (list? (member (Grupo-numero g) pedidos)))
              (Curso-grupos curso))))

;; Las opciones de un curso: una Seleccion por cada grupo aceptado.
;; Si el curso no existe o no esta habilitado, no tiene opciones
(: opciones-del-interes (-> Catalogo Interes (Listof Seleccion)))
(define (opciones-del-interes catalogo interes)
  (define curso (curso-por-codigo (Interes-codigo interes) catalogo))
  (if (and curso (habilitado? curso))
      (map (lambda ([g : Grupo]) (Seleccion curso g))
           (grupos-aceptados curso interes))
      '()))

;; Una lista de opciones por cada curso de interes que se puede matricular
(: armar-opciones (-> Catalogo Preferencias (Listof (Listof Seleccion))))
(define (armar-opciones catalogo prefs)
  (filter (lambda ([opciones : (Listof Seleccion)]) (not (null? opciones)))
          (map (lambda ([i : Interes]) (opciones-del-interes catalogo i))
               (Preferencias-intereses prefs))))

;; Codigos de los cursos de interes que no se pueden usar
(: cursos-omitidos (-> Catalogo Preferencias (Listof String)))
(define (cursos-omitidos catalogo prefs)
  (map Interes-codigo
       (filter (lambda ([i : Interes])
                 (null? (opciones-del-interes catalogo i)))
               (Preferencias-intereses prefs))))

;; --- Paso 2: generar las combinaciones ---

;; Todos los subconjuntos de una lista, como stream.
;; Sirve para cualquier tipo de elemento.
(: subconjuntos (All (A) (-> (Listof A) (Streamof (Listof A)))))
(define (subconjuntos lista)
  (if (null? lista)
      (stream '())
      (let ([resto (subconjuntos (cdr lista))])
        (stream-append
         (stream-map (lambda ([s : (Listof A)]) (cons (car lista) s)) resto)
         resto))))

;; Para cada subconjunto de cursos genera sus combinaciones sin choques.
;; Une todos los resultados en un solo stream.
(: combinaciones-por-subconjunto
   (-> (Streamof (Listof (Listof Seleccion)))
       (Listof ParChoque)
       (Streamof (Listof Seleccion))))
(define (combinaciones-por-subconjunto subconjuntos-de-cursos choques)
  (if (stream-empty? subconjuntos-de-cursos)
      empty-stream
      (stream-append
       (combinaciones-sin-choques (stream-first subconjuntos-de-cursos) choques)
       (combinaciones-por-subconjunto (stream-rest subconjuntos-de-cursos)
                                      choques))))

;; Suma los creditos de los cursos elegidos
(: armar-combinacion (-> (Listof Seleccion) Combinacion))
(define (armar-combinacion selecciones)
  (Combinacion
   selecciones
   (foldl (lambda ([s : Seleccion] [total : Integer])
            (+ total (Curso-creditos (Seleccion-curso s))))
          0
          selecciones)))

;; Todas las combinaciones validas: sin choques y dentro del rango de creditos
(: generar (-> Catalogo Preferencias (Streamof Combinacion)))
(define (generar catalogo prefs)
  (define cursos-posibles
    (stream-filter pair? (subconjuntos (armar-opciones catalogo prefs))))
  (define sin-choques
    (combinaciones-por-subconjunto cursos-posibles (Catalogo-choques catalogo)))
  (filtrar-rango-creditos Combinacion-creditos-totales
                          prefs
                          (stream-map armar-combinacion sin-choques)))

;; --- Paso 3: programa completo ---

;; Carga los archivos, genera y exporta. Devuelve cuantas combinaciones escribio
(: ejecutar (-> Path-String Path-String Path-String Natural))
(define (ejecutar ruta-catalogo ruta-preferencias ruta-salida)
  (define catalogo (cargar-catalogo ruta-catalogo))
  (define prefs
    (validarPreferencias (cargarPreferencias ruta-preferencias) catalogo))
  (define omitidos (cursos-omitidos catalogo prefs))
  (unless (null? omitidos)
    (eprintf "Aviso: se omiten cursos que no se pueden matricular: ~a\n"
             (string-join omitidos ", ")))
  (define total (exportar-combinaciones (generar catalogo prefs) prefs ruta-salida))
  (printf "~a combinaciones escritas en ~a\n" total ruta-salida)
  total)

;; Uso: racket main.rkt [catalogo preferencias salida]
(module+ main
  (define argumentos (vector->list (current-command-line-arguments)))
  (match argumentos
    [(list catalogo preferencias salida)
     (void (ejecutar catalogo preferencias salida))]
    ['()
     (void (ejecutar "Output/catalogoExp.json"
                     "Estudiantes/Preferencias/PreferenciasEstudiante1.json"
                     "Output/combinaciones.json"))]
    [_ (error 'main "uso: racket main.rkt [catalogo preferencias salida]")]))
