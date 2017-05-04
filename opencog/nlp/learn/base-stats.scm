;
; base-states.scm
;
; Return assorted database statistics
;
; Copyright (c) 2017 Linas Vepstas
;
; ---------------------------------------------------------------------
; The statistics reported here are those collected via the code
; in `link-pipeline.scm` and computed in `sompute-mi.scm`.  Therefore
; structure defintions there and here need to be maintained
; consistently.
; ---------------------------------------------------------------------
;
(use-modules (srfi srfi-1))
(use-modules (opencog))
(use-modules (opencog persist))

; ---------------------------------------------------------------------
(define-public (get-sentence-count)
"
  get-sentence-count -- get the number of sentences observed.
  This does fetch the count from the database. 

  This count is maintained by the link-pipeline code.
"
	(get-count (fetch-atom (SentenceNode "ANY")))
)

(define-public (get-parse-count)
"
  get-parse-count -- get the number of parses observed.
  This does fetch the count from the database. 

  This count is maintained by the link-pipeline code.
"
	(get-count (fetch-atom (ParseNode "ANY")))
)

(define-public (avg-sentence-length)
"
  avg-sentence-length -- get expected value for the number of words
  in the sentence.
"
	; Each word is counted once, in every parse.
	(/ (total-word-observations) (get-parse-count))
)

; ---------------------------------------------------------------------
; misc utilities of research interest
; XXX not everything below is correct!   Use with caution!

(define-public (get-left-word-of-pair PAIR)
"
  get-left-word-of-pair PAIR -- Given the EvaluationLink PAIR holding
  a word-pair, return the word on the left.
"
	(gadr PAIR)
)

(define-public (get-right-word-of-pair PAIR)
"
  get-right-word-of-pair PAIR -- Given the EvaluationLink PAIR holding
  a word-pair, return the word on the right.
"
	(gddr PAIR)
)

(define-public (get-all-pairs)
"
  get-all-pairs - return a list holding all of the observed word-pairs
  Caution: this can be tens of millions long!
"
	; The list of pairs is mostly just the incoming set of the ANY node.
	; However, this does include some junk, sooo ... hey, both left and
	; right better be words.
	(filter!
		(lambda (pair)
			(and
				(equal? 'WordNode (cog-type (get-left-word-of-pair pair)))
				(equal? 'WordNode (cog-type (get-right-word-of-pair pair)))))
		(cog-incoming-by-type any-pair-pred 'EvaluationLink))
)

(define-public (total-word-observations)
"
  total-word-observations -- return a total of the number of times
  any/all words were observed.  That is, compute and return N(*),
  as defined above, and in the diary.  This does NOT work from a
  cached value.  Also, this does NOT fetch atoms from the database!
"
   (get-total-atom-count (get-all-words))
)

(define-public (total-pair-observations)
"
  total-pair-observations -- return a total of the number of times
  any/all word-pairs were observed. That is, return N(*,*) as defined
  above, and in the diary.
"
	; Just get the previously computed amount.
	(get-count
		(EvaluationLink any-pair-pred
			(ListLink
				(AnyNode "left-word")
				(AnyNode "right-word"))))
)

(define-public (get-left-count-str WORD-STR)
"
  get-left-count-str WORD-STR
  Return the number of times that WORD-STR occurs in the left side
  of the \"ANY\" relationship. That is, return N(w, *), as defined above,
  and in the diary.  Here, w is WORD-STR, assumed to be a string.
"
	;; the wildcard is on the right.
	(get-count (get-any-right-wildcard (WordNode WORD-STR)))
)

(define-public (get-right-count-str WORD-STR)
"
  get-right-count-str WORD-STR
  Return the number of times that WORD-STR occurs in the right side
  of the \"ANY\" relationship. That is, return N(*, w), as defined above,
  and in the diary.  Here, w is WORD-STR, assumed to be a string.
"
	;; the wildcard is on the left.
	(get-count (get-any-left-wildcard (WordNode WORD-STR)))
)

(define-public (get-word-count-str WORD-STR)
"
  get-word-count-str WORD-STR
  Return the number of times that WORD-STR has ben observed. That is,
  return N(w) as defined in the diary. Here, w is WORD-STR, assumed to
  be a string.
"
	(get-count (WordNode WORD-STR))
)

(define-public (get-total-cond-prob ALL-PAIRS)
"
  get-total-cond-prob ALL-PAIRS -- return the total conditional
  probability of seeing the all word-pairs.  That is, return the
  sum over left and right words w_l, w_r of  N(w_l, w_r) / (N(w_l) N(w_r))

  Contrast this result with that of get-total-pair-prob
"
	; Return N(w_l, w_r) / N(w_l) N(w_r)
	(define (term pair)
		(/ (get-count pair)
			(* (get-count (get-left-word-of-pair pair))
				(get-count (get-right-word-of-pair pair)))))

	; textbook tail-recursive solution.
	(define (term-sum lst cnt)
		(if (null? lst) cnt
			(term-sum (cdr lst) (+ cnt (term (car lst))))))

	(term-sum ALL-PAIRS 0)
)

(define-public (get-total-pair-prob ALL-PAIRS)
"
  get-total-pair-prob - return the total pair-wise conditional
  probability of seeing a word-pair.  That is, return the sum over
  left and right words w_l, w_r of
      N(w_l, w_r) / (N(w_l, *) N(*, w_r))

  Contrast this result with that of get-total-cond-prob
"

	; Return N(w_l, w_r) / N(w_l) N(w_r)
	(define (term pair)
		(/ (get-count pair)
			(* (get-count (get-left-word-of-pair pair))
				(get-count (get-right-word-of-pair pair)))))

	; textbook tail-recursive solution.
	(define (term-sum lst cnt)
		(if (null? lst) cnt
			(term-sum (cdr lst) (+ cnt (term (car lst))))))

	(term-sum ALL-PAIRS 0)
)

; ---------------------------------------------------------------------