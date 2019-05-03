#lang racket/base

(provide loop)

(require syntax/parse/define
         (for-syntax racket/base
                     syntax/stx))

(begin-for-syntax
  (define-syntax-class binding
    #:description "binding"
    (pattern [name:id val:expr]))

  (define-syntax-class binding*
    #:description "binding"
    (pattern [name:id val:expr #:default (~optional def:expr)]
             #:with default #'(~? def val))
    (pattern [name:id val:expr #:inherit]
             #:with default #'name))

  (define id->kw (compose1 string->keyword
                           symbol->string
                           syntax->datum)))

(define-syntax-parser loop
  [(_ name:id ((~alt binds:binding binds*:binding*) ...) body:expr ...+)
   #:with (kwargs ...) (stx-map id->kw #'(binds*.name ...))
   #'(let loop ([binds.name binds.val] ... [binds*.name binds*.val] ...)
       (define (name binds.name ... (~@ kwargs [binds*.name binds*.default]) ...)
         (loop binds.name ... binds*.name ...))
       (let () body ...))])

(module+ test
  (require rackunit
           racket/match)

  ;; sum even numbers
  (check-equal?
   (loop @ ([n 5] [sum 0 #:inherit])
     (cond
       [(= 0 n) sum]
       [(= 0 (remainder n 2)) (@ (sub1 n) #:sum (+ sum n))]
       [(= 1 (remainder n 2)) (@ (sub1 n))]))
   (+ 4 2))

  ;; sum numbers after even numbers
  (check-equal?
   (loop @ ([xs '(4 4 7 3 2 5 8 5)]
            [sum 0]
            [proceed? #f #:default])
     (match xs
       ['() sum]
       [(list (? even? x) xs ...)
        (@ xs (if proceed? (+ sum x) sum) #:proceed? #t)]
       [(list x xs ...)
        (@ xs (if proceed? (+ sum x) sum))]))
   (+ 4 7 5 5))

  ;; sum numbers after even numbers and the first number
  (check-equal?
   (loop @ ([xs '(4 4 7 3 2 5 8 5)]
            [proceed? #t #:default #f]
            [sum 0])
     (match xs
       ['() sum]
       [(list (? even? x) xs ...)
        (@ xs (if proceed? (+ sum x) sum) #:proceed? #t)]
       [(list x xs ...)
        (@ xs (if proceed? (+ sum x) sum))]))
   (+ 4 4 7 5 5)))
