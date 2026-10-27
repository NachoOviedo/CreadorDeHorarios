#lang typed/racket

;; flujo.rkt: streams perezosos con tipos.
;; Typed Racket no trae tipos para racket/stream, asi que se definen aqui.
;; Un stream es vacio o una celda con su primer elemento y una promesa
;; que calcula el resto solo cuando alguien lo pide.

(provide Streamof
         empty-stream
         stream-cons
         stream
         stream-empty?
         stream-first
         stream-rest
         stream-append
         stream-map
         stream-filter
         stream-take
         stream->list)

(struct Vacio ())
(struct (A) Celda ([primero : A] [resto : (Promise (Streamof A))]))

(define-type (Streamof A) (U Vacio (Celda A)))

(define empty-stream : Vacio (Vacio))

;; Construye un stream; el resto no se calcula hasta que se necesite
(define-syntax-rule (stream-cons primero resto)
  (Celda primero (delay resto)))

(: stream-empty? (-> (Streamof Any) Boolean))
(define (stream-empty? s)
  (Vacio? s))

(: stream-first (All (A) (-> (Streamof A) A)))
(define (stream-first s)
  (if (Vacio? s)
      (error 'stream-first "el stream esta vacio")
      (Celda-primero s)))

(: stream-rest (All (A) (-> (Streamof A) (Streamof A))))
(define (stream-rest s)
  (if (Vacio? s)
      (error 'stream-rest "el stream esta vacio")
      (force (Celda-resto s))))

;; Stream con los elementos dados
(: stream (All (A) (-> A * (Streamof A))))
(define (stream . elementos)
  (if (null? elementos)
      empty-stream
      (stream-cons (car elementos) (apply stream (cdr elementos)))))

;; Une dos streams. El segundo no se calcula hasta que el primero se acaba
(: unir (All (A) (-> (Streamof A) (Promise (Streamof A)) (Streamof A))))
(define (unir s otro)
  (if (Vacio? s)
      (force otro)
      (Celda (Celda-primero s)
             (delay (unir (force (Celda-resto s)) otro)))))

(define-syntax-rule (stream-append primero segundo)
  (unir primero (delay segundo)))

(: stream-map (All (A B) (-> (-> A B) (Streamof A) (Streamof B))))
(define (stream-map f s)
  (if (Vacio? s)
      empty-stream
      (Celda (f (Celda-primero s))
             (delay (stream-map f (force (Celda-resto s)))))))

(: stream-filter (All (A) (-> (-> A Boolean) (Streamof A) (Streamof A))))
(define (stream-filter criterio s)
  (cond
    [(Vacio? s) empty-stream]
    [(criterio (Celda-primero s))
     (Celda (Celda-primero s)
            (delay (stream-filter criterio (force (Celda-resto s)))))]
    [else (stream-filter criterio (force (Celda-resto s)))]))

;; Los primeros n elementos
(: stream-take (All (A) (-> (Streamof A) Natural (Streamof A))))
(define (stream-take s n)
  (if (or (zero? n) (Vacio? s))
      empty-stream
      (Celda (Celda-primero s)
             (delay (stream-take (force (Celda-resto s)) (sub1 n))))))

(: stream->list (All (A) (-> (Streamof A) (Listof A))))
(define (stream->list s)
  (if (Vacio? s)
      '()
      (cons (Celda-primero s) (stream->list (force (Celda-resto s))))))
