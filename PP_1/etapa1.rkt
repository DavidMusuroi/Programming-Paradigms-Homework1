#lang racket
(require racket/match)
(require racket/trace)

(provide (all-defined-out))

(define ITEMS 5)

;; C1, C2, C3, C4 sunt case într-un magazin.
;; C1 acceptă doar clienți care au cumpărat maxim ITEMS produse
;; (ITEMS este definit mai sus).
;; C2 - C4 nu au restricții.
;; Considerăm că procesarea fiecărui produs la casă durează un minut.
;; Casele pot suferi întârzieri (delay).
;; La un moment dat, la fiecare casă există
;; 0 sau mai mulți clienți care stau la coadă.
;; Timpul total (tt) al unei case reprezintă
;; timpul de procesare al celor aflați la coadă,
;; adică numărul de produse cumpărate de ei +
;; întârzierile suferite de casa respectivă (dacă există).
;; Ex:
;; la C3 sunt Ana cu 3 produse și Geo cu 7 produse,
;; și C3 nu are întârzieri => tt pentru C3 este 10.


; Definim o structură care descrie o casă prin:
; - index (de la 1 la 4)
; - tt (timpul total descris mai sus)
; - queue (coada cu persoanele care așteaptă)
(define-struct counter (index tt queue) #:transparent)

; TODO 1 (10p)
; Implementați o funcție care întoarce o structură counter goală.
; tt este 0 si coada este vidă.
; Obs: la definirea structurii counter se creează automat
; o funcție make-counter pentru a construi date de acest tip
(define (empty-counter index)
  (make-counter index 0 '()))


; TODO 2 (10p)
; Implementați o funcție care crește tt-ul unei case
; cu un număr dat de minute.
(define (tt+ C minutes)
  (struct-copy counter C [index (counter-index C)] [tt (+(counter-tt C) minutes)]))


; TODO 3 (20p)
; Implementați o funcție care primește o listă nevidă 
; de case și întoarce o pereche dintre:
; - indexul casei (din listă) care are cel mai mic tt
; - tt-ul acesteia
; Obs: când mai multe case au același tt,
; este preferată casa cu indexul cel mai mic
; RESTRICȚII (20p):
;  - Folosiți recursivitate pe coadă.

(define (min-tt-helper counters minim index)
  (if (empty? counters)
    (cons index minim)
    (if (< minim (counter-tt(car counters)))
      (min-tt-helper (cdr counters) minim index)
      (if (equal? minim (counter-tt(car counters)))
        (min-tt-helper (cdr counters) minim (min index (counter-index(car counters))))
        (min-tt-helper (cdr counters) (counter-tt(car counters)) (counter-index(car counters)))))))

(define (min-tt counters)
  (min-tt-helper counters (counter-tt(car counters)) (counter-index(car counters))))

; (trace min-tt-helper)

; TODO 4 (20p)
; Implementați aceeași funcționalitate de mai sus,
; cu recursivitate pe stivă.
; RESTRICȚII (20p):
;  - Folosiți recursivitate pe stivă.

(define (min-tt-stack counters)
  (if (equal? 1 (length counters))
    (cons (counter-index(car counters)) (counter-tt(car counters)))
    (if (< (counter-tt(car counters)) (cdr(min-tt-stack (cdr counters))))
      (cons (counter-index(car counters)) (counter-tt(car counters)))
      (if (equal? (counter-tt(car counters)) (cdr(min-tt-stack (cdr counters))))
        (cons (min (counter-index(car counters)) (car(min-tt-stack (cdr counters)))) (counter-tt(car counters)))
        (min-tt-stack (cdr counters))))))

; (trace min-tt-stack)

; TODO 5 (10p)
; Implementați o funcție care adaugă o persoană la o casă.
; C = casa, name = numele persoanei,
; n-items = numărul de produse cumpărate
; Veți întoarce o nouă structură obținută prin așezarea perechii
; (name . n-items) la sfârșitul cozii de așteptare.
(define (add-to-counter C name n-items)
  (make-counter (counter-index C) (+ (counter-tt C) n-items) (append (counter-queue C) (list(cons name n-items)))))


; TODO 6 (50p)
; Implementați funcția care simulează fluxul clienților pe la case.
; requests = listă de cereri care pot fi de 2 tipuri:
; - (<name> <n-items>) - așază persoana <name> la coadă la o casă
; - (delay <index> <minutes>) - întârzie casa <index> cu <minutes> minute
; C1, C2, C3, C4 = structuri corespunzătoare celor 4 case
; Sistemul procesează cererile în ordine, astfel:
; - așază persoana la casa cu tt minim la care are voie
;   (conform logicii implementate de min-tt)
; - când o casă suferă o întârziere, tt-ul ei crește
(define (serve requests C1 C2 C3 C4)
  
  ; Puteți să vă definiți aici funcții ajutătoare (define în define)
  ; - avantaj: aveți acces la variabilele
  ;   requests, C1, C2, C3, C4 fără a le retrimite ca parametri
  ; Puteți să vă definiți funcții ajutătoare în exteriorul lui "serve"
  ; - avantaj: puteți testa fiecare funcție imediat ce ați implementat-o
  ; Nu este obligatoriu să definiți funcții ajutătoare.
  (define (get_casa index)
    (if (equal? index 1)
      C1
      (if (equal? index 2)
        C2
        (if (equal? index 3)
          C3
          C4))))

  (define (call_serve casa index)
    (cond 
      [(= index 1) (serve (cdr requests) casa C2 C3 C4)]
      [(= index 2) (serve (cdr requests) C1 casa C3 C4)]
      [(= index 3) (serve (cdr requests) C1 C2 casa C4)]
      [(= index 4) (serve (cdr requests) C1 C2 C3 casa)]))

  (if (null? requests)
      (list C1 C2 C3 C4)
      (match (car requests)
        [(list 'delay index minutes)
          (define new_casa (tt+ (get_casa index) minutes))
          (call_serve new_casa index)]
        [(list name n-items)
          (define new_casa_without_C1 (get_casa(car(min-tt(list C2 C3 C4)))))
          (define new_casa_with_C1 (get_casa(car(min-tt(list C1 C2 C3 C4)))))
          (if (> n-items ITEMS)
            (call_serve (add-to-counter new_casa_without_C1 name n-items) (car(min-tt(list C2 C3 C4))))
            (call_serve(add-to-counter new_casa_with_C1 name n-items) (car(min-tt(list C1 C2 C3 C4)))))])))