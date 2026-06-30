#lang racket
(require racket/match)
(require "queue.rkt")

(provide (all-defined-out))

(define ITEMS 5)

;; ATENȚIE: Este necesar să implementați întâi
;;          TDA-ul queue în fișierul queue.rkt.
;; Reveniți la acest fișier după ce ați implementat tipul 
;; queue și ați verificat implementarea folosind checker-ul.


; Structura counter nu se modifică.
; Se modifică însă implementarea câmpului queue:
; - în loc de listă, acesta va fi o structură de tip queue
; - modificarea nu este vizibilă în definiția structurii,
;   ci în implementarea operațiilor tipului counter
(define-struct counter (index tt et queue) #:transparent)


; TODO 6 (20p)
; Actualizați funcțiile de mai jos conform cu 
; noua reprezentare a cozii de persoane.
; Elementele cozii rămân perechi (nume . nr_produse).
; RESTRICȚII (5p per abatere)
;  - Respectați "bariera de abstractizare", adică 
;    operați cu coada folosind exclusiv interfața:
;    - empty-queue
;    - queue-empty?
;    - enqueue
;    - dequeue
;    - top
; Obs: Doar câteva funcții necesită actualizări.
(define (empty-counter index)           ; testată de checker
  (make-counter index 0 0 empty-queue))

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
      (make-counter (counter-index C) (+ (counter-tt C) items) (+ (counter-et C) items) (enqueue (cons name items) (counter-queue C)))
      (make-counter (counter-index C) (+ (counter-tt C) items) (counter-et C) (enqueue (cons name items) (counter-queue C)))))
  ; nu modificați signatura!
    
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

(define (add_tt q suma)
  (if (equal? (length q) 0)
    suma
    (add_tt (cdr q) (+ suma (cdr(car q))))))

(define (remove-first-from-counter C)   ; testată de checker
  (if (queue-empty? (dequeue(counter-queue C)))
    (empty-counter (counter-index C))
    (make-counter (counter-index C) (- (counter-tt C) (counter-et C)) (cdr(top(dequeue(counter-queue C)))) (dequeue(counter-queue C)))))


; TODO 7 (10p)
; Implementați o funcție care calculează starea
; unei case după un număr dat de minute.
; Funcția presupune, fără să verifice, că în acest timp
; nu iese nimeni din coadă, deci se modifică
; doar câmpurile tt și et.
; Este responsabilitatea utilizatorului să nu apeleze
; funcția cu minutes > et și coadă nevidă.
; La casele fără clienți, este responsabilitatea
; voastră să nu produceți timpi negativi.
(define ((pass-time-through-counter minutes) C)
  (cond 
    [(and (<= (counter-tt C) minutes) (<= (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt 0] [et 0])]
    [(and (<= (counter-tt C) minutes) (> (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt 0] [et (- (counter-et C) minutes)])]
    [(and (> (counter-tt C) minutes) (<= (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt (- (counter-tt C) minutes)] [et 0])]
    [(and (> (counter-tt C) minutes) (> (counter-et C) minutes)) (struct-copy counter C [index (counter-index C)] [tt (- (counter-tt C) minutes)] [et (- (counter-et C) minutes)])]
  ))
  

; TODO 8 (60p)
; Implementați funcția care simulează fluxul clienților pe la case.
; ATENȚIE: Față de etapa 2, apar modificări în:
; - formatul listei de cereri (requests)
; - formatul rezultatului funcției (explicat mai jos)
; requests conține 4 tipuri de cereri:
;   3 moștenite din etapa 2:
;   - (<name> <n-items>) - așază persoana <name> la coadă la o casă
;   - (delay <index> <minutes>) - întârzie casa <index> cu <minutes> minute
;   - (ensure <average>) - cât timp tt-ul mediu al tuturor caselor depășește 
;                          <average>, adaugă case fără restricții (case slow)
;   plus noutatea:
;   - <x> - actualizează starea caselor conform cu trecerea a <x> minute
;           de la ultima cerere (afectează câmpurile tt, et, queue)
; Obs: Cererile (remove-first) din etapa 2 sunt înlocuite de un mecanism  
; mai sofisticat de a scoate clienții din coadă (pe măsură ce trece timpul).
; Sistemul procesează cererile în ordine, astfel:
; - nicio modificare pentru cererile moștenite din etapa 2
; - când timpul prin sistem avansează cu <x> minute, starea caselor
;   se actualizează pentru a reflecta trecerea timpului;
;   ieșirile clienților din coadă se rețin în ordine cronologică.
; Funcția serve întoarce o pereche cu punct între:
; - lista clienților care au părăsit magazinul, sortată cronologic
;   - elementele listei au forma (index_casă . nume)
;   - când mai mulți clienți ies simultan, sortați după indexul casei
; - lista caselor în starea finală (ca rezultatul din etapele 1 și 2)
; Sugestii:
; - gestionați cronologia folosind în mod repetat funcția min-et 
; - pentru a menține lista clienților plecați, definiți o funcție ajutătoare
; (cu un parametru în plus față de serve), pe care serve doar o apelează.
; RESTRICȚII (5p per abatere)
;  - Folosiți minim un let și un let* (care nu ar putea fi let). (2*5p)
;  - Respectați "bariera de abstractizare" oricând operați cu tipul queue.
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
  (define (get_average_tt counters)
    (/ (get_suma_tt counters) (length counters)))

  (define (keep_adding_counters nr fast-counters slow-counters)
    (if (> (get_average_tt (append fast-counters slow-counters)) nr)
      (keep_adding_counters nr fast-counters (append slow-counters (list (empty-counter (+ 1 (length(append fast-counters slow-counters)))))))
      (cons fast-counters slow-counters)))
        
  (define (serve-helper requests fast-counters slow-counters clienti_plecati)
    (if (null? requests)
      (cons clienti_plecati (append fast-counters slow-counters))
      (match (car requests)
        [(list 'delay index minutes)
          (define new_fast-counters (update (lambda (C) (apply_delay C minutes)) fast-counters index))
          (define new_slow-counters (update (lambda (C) (apply_delay C minutes)) slow-counters index))
          (serve-helper (cdr requests) new_fast-counters new_slow-counters clienti_plecati)]
        [(list 'ensure nr)
          (let ([rez (keep_adding_counters nr fast-counters slow-counters)])
          (serve-helper (cdr requests) (car rez) (cdr rez) clienti_plecati))]
        [(list name n-items)
          (define index1 (car(min-tt slow-counters)))
          (define index2 (car(min-tt(append fast-counters slow-counters))))
          (if (> n-items ITEMS)
            (serve-helper (cdr requests)
              (update (lambda (C) ((add-to-counter name n-items) C)) fast-counters index1)
              (update (lambda (C) ((add-to-counter name n-items) C)) slow-counters index1) clienti_plecati)
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