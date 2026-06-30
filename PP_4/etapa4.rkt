#lang racket
(require racket/match)
(require "queue.rkt")

(provide (all-defined-out))

(define ITEMS 5)


; TODO (0p)
; Aveți libertatea să vă structurați programul cum doriți
; (dar cu restricțiile de mai jos), astfel încât
; funcția serve să funcționeze conform specificației.
; 
; Restricții (impuse de checker):
; - va exista în continuare funcția (empty-counter index)
; - veți reprezenta cozile folosind noul TDA queue

(define-struct counter (index tt et queue open_or_closed) #:transparent)

(define (empty-counter index)
  (make-counter index 0 0 empty-queue #t))

(define (get_casa counter index f)
  (if (equal? (counter-index counter) index) 
    (f counter)
    counter))

(define (update f counters index)
  (define (apply_f counter)
    (get_casa counter index f))
  (map apply_f counters))

(define (tt+ C)
  (lambda (minutes)
    (struct-copy counter C [index (counter-index C)] [tt (+(counter-tt C) minutes)])))

(define (et+ C)
  (lambda (minutes)
    (struct-copy counter C [index (counter-index C)] [tt (counter-tt C)] [et (+(counter-et C) minutes)])))

(define ((add-to-counter name items) C) ; testată de checker
  (if (queue-empty?(counter-queue C))
      (make-counter (counter-index C) (+ (counter-tt C) items) (+ (counter-et C) items) (enqueue (cons name items) (counter-queue C)) (counter-open_or_closed C))
      (make-counter (counter-index C) (+ (counter-tt C) items) (counter-et C) (enqueue (cons name items) (counter-queue C)) (counter-open_or_closed C))))
  ; Am adaugat open_or_closed la make-counter

(define (curry-min-helper counters minim index f)
  (if (empty? counters)
    (cons index minim)
    (if (< minim (f(car counters)))
      (curry-min-helper (cdr counters) minim index f)
      (if (equal? minim (f(car counters)))
        (curry-min-helper (cdr counters) minim (min index (counter-index(car counters))) f)
        (curry-min-helper (cdr counters) (f(car counters)) (counter-index(car counters)) f)))))

(define (curry-min f)
  (lambda (counters)
    (curry-min-helper counters (f(car counters)) (counter-index(car counters)) f)))
(define min-tt (curry-min counter-tt))
(define min-et (curry-min counter-et))

(define (remove-first-from-counter C)   ; testată de checker
  (if (queue-empty? (dequeue(counter-queue C)))
    (struct-copy counter C [tt 0] [et 0] [queue empty-queue])
    (make-counter (counter-index C) (- (counter-tt C) (counter-et C)) (cdr(top(dequeue(counter-queue C)))) (dequeue(counter-queue C)) (counter-open_or_closed C))))
    ; Am adaugat open_or_closed la make-counter

(define ((pass-time-through-counter minutes) C)
  (cond 
    [(and (<= (counter-tt C) minutes) (<= (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt 0] [et 0])]
    [(and (<= (counter-tt C) minutes) (> (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt 0] [et (- (counter-et C) minutes)])]
    [(and (> (counter-tt C) minutes) (<= (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt (- (counter-tt C) minutes)] [et 0])]
    [(and (> (counter-tt C) minutes) (> (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt (- (counter-tt C) minutes)] [et (- (counter-et C) minutes)])]
  ))
  
  
; TODO 7 (70p)
; Implementați funcția care simulează fluxul clienților pe la case.
; ATENȚIE: Față de etapa 3, apar modificări în:
; - formatul listei de cereri (requests)
; - formatul rezultatului funcției (explicat mai jos)
; requests conține 6 tipuri de cereri:
;   4 moștenite din etapa 3:
;   - (<name> <n-items>) - așază persoana <name> la coadă la o casă deschisă
;   - (delay <index> <minutes>) - întârzie casa <index> cu <minutes> minute
;   - (ensure <average>) - cât timp tt-ul mediu al caselor deschise depășește 
;                          <average>, adaugă case fără restricții (case slow)
;   - <x> - actualizează starea caselor conform cu trecerea a <x> minute
;           de la ultima cerere (afectează câmpurile tt, et, queue)
;   plus 2 noi:
;   - (close <index>) - închide casa cu indexul <index> (casa există deja)
;   - (open <index>) - deschide casa cu indexul <index> (casa există deja)
; Sistemul procesează cererile în ordine, astfel:
; - așază persoana la casa DESCHISĂ cu tt minim la care are voie;
;   se garantează că persoana poate fi distribuită la o casă
; - nicio modificare pentru situația când o casă suferă o întârziere
; - dacă tt-ul mediu pentru toate casele DESCHISE > <average>,
;   adaugă case slow până când media <= <average>
; - nicio modificare în modelarea trecerii timpului
; - o casă care se închide nu mai primește clienți noi și:
;   - primul client (dacă există) își continuă treaba la această casă
;   - restul clienților se redistribuie la celelalte case,
;     în ordinea în care erau așezați la coadă
; - o casă care se deschide redevine disponibilă pentru clienți
; Funcția serve întoarce o pereche cu punct între:
; - lista clienților care au părăsit magazinul, sortată cronologic
;   - elementele listei au forma (index_casă . nume)
;   - când mai mulți clienți ies simultan, sortați după indexul casei
; - lista cozilor nevide în starea finală, sortată după indexul casei
;   - elementele listei au forma (index_casă . coadă) (coada este de tip queue)
(define (serve requests fast-counters slow-counters)

  (define (apply_delay C minutes)
    (define casa ((tt+ C) minutes))
    ((et+ casa) minutes))

  (define (check_if_null C)
    (not (queue-empty? (counter-queue C))))

  (define (get_suma_tt counters)
    (if(equal?(length counters) 0)
      0
      (+ (counter-tt (car counters)) (get_suma_tt(cdr counters)))))

  ; Media aritmetica se va calcula doar pe casele deschise
  (define (get_average_tt counters)
    (define case_open (filter counter-open_or_closed counters))
    (/ (get_suma_tt case_open) (length case_open)))

  (define (keep_adding_counters nr fast-counters slow-counters)
    (if (> (get_average_tt (append fast-counters slow-counters)) nr)
      (keep_adding_counters nr fast-counters (append slow-counters (list (empty-counter (+ 1 (length(append fast-counters slow-counters)))))))
      (cons fast-counters slow-counters)))

  (define (get_first_from_queue q)
    (if (queue-empty? q)
      empty-queue
      (enqueue (top q) empty-queue)))

  (define (get_clienti q)
    (if (queue-empty? q)
      '()
      (cons (top q) (get_clienti (dequeue q)))))
        
  (define (serve-helper requests fast-counters slow-counters clienti_plecati)
    (if (null? requests)
      (let* (
        [case_notempty (filter check_if_null (append fast-counters slow-counters))]
        [sort_by_index_asc (sort case_notempty 
          (lambda (a b) (< (counter-index a) (counter-index b))))]
        [index_queue_pair (map (lambda (counter) (cons (counter-index counter) (counter-queue counter))) sort_by_index_asc)])
        (cons clienti_plecati index_queue_pair))
      (match (car requests)
        [(list 'open index)
          (serve-helper (cdr requests)
            (update (lambda (C) (struct-copy counter C [open_or_closed #t])) fast-counters index)
            (update (lambda (C) (struct-copy counter C [open_or_closed #t])) slow-counters index) clienti_plecati)]
        [(list 'close index)
          (let* (
            [closed_casa (car (filter (lambda (C) (= index (counter-index C))) (append fast-counters slow-counters)))]
            [new_fast-counters (update (lambda (C) (struct-copy counter C [queue (get_first_from_queue (counter-queue closed_casa))] [open_or_closed #f])) fast-counters index)]
            [new_slow-counters (update (lambda (C) (struct-copy counter C [queue (get_first_from_queue (counter-queue closed_casa))] [open_or_closed #f])) slow-counters index)]
            [all_but_first (if (queue-empty? (counter-queue closed_casa))
              '()
              (get_clienti (dequeue (counter-queue closed_casa))))])
            (serve-helper (append (map (lambda (C) (list (car C) (cdr C))) all_but_first) (cdr requests)) new_fast-counters new_slow-counters clienti_plecati))]
        [(list 'delay index minutes)
          (define new_fast-counters (update (lambda (C) (apply_delay C minutes)) fast-counters index))
          (define new_slow-counters (update (lambda (C) (apply_delay C minutes)) slow-counters index))
          (serve-helper (cdr requests) new_fast-counters new_slow-counters clienti_plecati)]
        [(list 'ensure nr)
          (let ([rez (keep_adding_counters nr fast-counters slow-counters)])
          (serve-helper (cdr requests) (car rez) (cdr rez) clienti_plecati))]
        [(list name n-items)
          (define filter_slow (filter counter-open_or_closed slow-counters))
          (define filter_fast_and_slow (filter counter-open_or_closed (append fast-counters slow-counters)))
          (define index2 (car(min-tt filter_fast_and_slow)))
          (if (> n-items ITEMS)
            (let ([index1 (car(min-tt filter_slow))])
            (serve-helper (cdr requests)
              (update (lambda (C) ((add-to-counter name n-items) C)) fast-counters index1)
              (update (lambda (C) ((add-to-counter name n-items) C)) slow-counters index1) clienti_plecati))
            (serve-helper (cdr requests)
              (update (lambda (C) ((add-to-counter name n-items) C)) fast-counters index2)
              (update (lambda (C) ((add-to-counter name n-items) C)) slow-counters index2) clienti_plecati))]
        [x
          (let*(
            [get_counters (filter check_if_null (append fast-counters slow-counters))]
            [minimum_et (if (null? get_counters) '(0 . 999999999999) (min-et get_counters))]    
            [find_casa (if(null? get_counters)
              (empty-counter 0)
              (car(filter(lambda (C) (= (counter-index C) (car minimum_et))) get_counters)))]    
            [find_name (if(null? get_counters)
              'nimeni
              (car(top(counter-queue find_casa))))])
            (if(or(null? get_counters) (< x (cdr minimum_et)))
              (serve-helper (cdr requests) (map (pass-time-through-counter x) fast-counters) (map (pass-time-through-counter x) slow-counters) clienti_plecati)
              (serve-helper (cons (- x (cdr minimum_et)) (cdr requests)) 
              (update remove-first-from-counter(map (pass-time-through-counter (cdr minimum_et)) fast-counters) (car minimum_et))
              (update remove-first-from-counter(map (pass-time-through-counter (cdr minimum_et)) slow-counters) (car minimum_et))
              (append clienti_plecati (list(cons(car minimum_et) find_name))))))])))

    (serve-helper requests fast-counters slow-counters '()))