#lang scribble/manual
@(require scribble/example
          (for-label racket/base racket/match loop))

@(define the-eval (make-base-eval))
@(the-eval '(require loop))
@(the-eval '(require racket/match))

@title{loop: advanced named let}
@author+email["Sorawee Porncharoenwase" "sorawee.pwase@gmail.com"]

@defmodule[loop]

This library provides the @racket[loop] syntax, a drop-in replacement of named @racket[let]. Unlike named let, the loop syntax has an option that will allow unchanged variables to be left out in function calls, as they will be carried to the next loop automatically. It also supports customized default values.

The code of this library can be found at @url{https://github.com/sorawee/loop}.

@section{Examples}

Let's suppose that you want to calculate the sum of even numbers up to @racket[42]. One dumb way is to use named @racket[let] to iterate from 42 to 1 and add even numbers together.

@examples[#:eval the-eval #:label #f
(let go ([n 42] [sum 0])
  (cond
    [(= n 0) sum]
    [(even? n) (go (sub1 n) (+ sum n))]
    [else (go (sub1 n) sum)]))
]

Notice that the variable @racket[sum] is left unchanged in the else branch. With the @racket[loop] syntax, we can write the following instead:

@examples[#:eval the-eval #:label #f
(loop go ([n 42] [sum 0 #:inherit])
  (cond
    [(= n 0) sum]
    [(even? n) (go (sub1 n) #:sum (+ sum n))]
    [else (go (sub1 n))]))
]

Admittedly, this is not a perfect example because there are only few variables, so it doesn't look really worth converting from the named let to the loop version. However, as the number of variables increases, the loop version will have an edge on. The loop version is also more scalable: adding more variables doesn't require changing every recursive call.

As another example, let's suppose we want to sum every number in a list that is after an even number. One dumb way using named let is as follows:

@examples[#:eval the-eval #:label #f
(let go ([xs '(4 4 7 3 2 5 8 5)] [sum 0] [proceed? #f])
  (match xs
    ['() sum]
    [(list (? even? x) xs ...) (go xs (if proceed? (+ sum x) sum) #t)]
    [(list x xs ...) (go xs (if proceed? (+ sum x) sum) #f)]))
]

Notice that by default, @racket[proceed?] is @racket[#f], and the variable is flipped to @racket[#t] only when @racket[x] is even. With the @racket[loop] construct, we can write the following instead:

@examples[#:eval the-eval #:label #f
(loop go ([xs '(4 4 7 3 2 5 8 5)] [sum 0] [proceed? #f #:default])
  (match xs
    ['() sum]
    [(list (? even? x) xs ...)
     (go xs (if proceed? (+ sum x) sum) #:proceed? #t)]
    [(list x xs ...)
     (go xs (if proceed? (+ sum x) sum))]))
]

@section{The Loop}

@defform[(loop proc-id ([id-required/optional init-expr extra-options] ...)
           body ...+)
         #:grammar
         [(extra-option (code:line)
                        #:inherit
                        #:default
                        (code:line #:default default-expr))]]{
  Evaluates the @racket[init-expr]s; the resulting values become arguments in an application of a procedure @racket[(lambda (id-required ... #:id-optional [id-optional default-val] ...) body ...+)], where @racket[proc-id] is bound within the @racket[body]s to the procedure itself. For @racket[id-optional], @racket[default-val] is either:

  @itemlist[
    @item{The value of @racket[id-optional] in the previous loop, if @racket[#:inherit] is specified.}
    @item{The result of the evaluation of @racket[init-expr], if @racket[#:default] is specified, but @racket[default-expr] is not.}
    @item{The result of the evaluation of @racket[default-expr], if both @racket[#:default] and @racket[default-expr] are specified.}
  ]
}

@section{Performance}

Keyword arguments are incredibly very expensive. It could, for instance, make a program slower by 5x. Thankfully, in usual circumstances, Racket will be able to perform function application inlining, which completely restores the performance back to the original level.

It is still possible to circumvent Racket from performing inlining, however. In this case, the performance degradation will be noticable.

@examples[#:eval the-eval #:label #f
(define N 10000000)

(code:comment @#,elem{Original performant code})
(time
 (let go ([n N] [sum 0])
   (cond
     [(= 0 n) sum]
     [(= 0 (remainder n 2)) (go (sub1 n) (+ sum n))]
     [(= 1 (remainder n 2)) (go (sub1 n) sum)])))

(code:comment @#,elem{Equally performant code with loop syntax})
(time
 (loop go ([n N] [sum 0 #:inherit])
   (cond
     [(= 0 n) sum]
     [(= 0 (remainder n 2)) (go (sub1 n) #:sum (+ sum n))]
     [(= 1 (remainder n 2)) (go (sub1 n))])))

(code:comment @#,elem{Non-performant code with loop syntax})
(code:comment @#,elem{due to the inability to perform inlining})
(time
 (loop go ([n N] [sum 0 #:inherit])
   (let ([go go])
     (cond
       [(= 0 n) sum]
       [(= 0 (remainder n 2)) (go (sub1 n) #:sum (+ sum n))]
       [(= 1 (remainder n 2)) (go (sub1 n))]))))
]