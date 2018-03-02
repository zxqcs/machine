;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;             The Assembler               ;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(load "machine.scm")



(define (assemble controller-text machine)
   (extract-labels controller-text
      (lambda (insts labels)
         (update-insts! insts labels machine) 
       insts)))


(define (extract-labels text receive)
   (if (null? text)
       (receive '() '())
       (extract-labels
         (cdr text)
         (lambda (insts labels)
            (let ((next-inst (car text)))
               (if (symbol? next-inst)
                   (receive
                      insts
                      (cons
                        (make-label-entry
                           next-inst insts labels))
                  (receive
                     (cons (make-instruction
                             next-inst)
                            insts)
                     labels))))))))


(define (update-insts! insts labels machine)
   (let ((pc (get-register machine 'pc))
        (flag (get-register machine 'flag))
        (stack (machine 'stack))
        (ops (machine 'operations)))
      (for-each
        (lambda (inst)
           (set-instruction-execution-proc!
             inst
            (make-execution-procedure
            (instruction-text inst)
            labels
            machine
            pc
            flag
            stack
            ops)))
      insts)))


(define (make-instruction text) (cons text '()))

(define (instruction-text inst) (car inst))

(define (instruction-execution-proc inst) (cdr inst))

(define (set-instruction-execution-proc! inst proc)
   (set-cdr! inst  proc))

(define (make-label-entry label-name insts) 
   (cons label-name insts))

(define (lookup-label labels label-name)
  (let ((val (assoc label-name labels)))
     (if val
         (cdr val)
         (error "Undefined label: ASSEMBLE" label-name))))


;; Generating Execution Procedures for Instructions
(define (make-execution-procedure
        inst labels machine pc flag stack ops)
  (cond ((eq? (car inst) 'assign)
         (make-assgin
          inst machine labels ops pc))
        ((eq? (car inst) 'test)
         (make-test
          inst machine labels ops flag pc))
        ((eq? (car inst) 'branch)
        (make-branch
        inst machine labels flag pc))
        ((eq? (car inst) 'goto)
        (make-goto inst machine labels pc))
        ((eq? (car inst) 'save)
        (make-save inst machine stack pc))
        ((eq? (car inst) 'restore)
         (make-restore inst machine stack pc))
        ((eq? (car inst) 'perform)
         (make-perform 
          inst machine lables ops pc))
        (else (error "Unknown instruction type: ASSEMBLE"
               inst))))


(define (make-assign inst machine labels operations pc)
   (let ((target
          (get-register
            machine
            (assign-reg-name inst)))
           (value-exp (assign-value-exp inst)))
     (let ((value-proc
             (if (operation-exp? value-exp)
                 (make-operation-exp
                  value-exp
                  machine
                  labels
                  operations)
                 (make-primitive-exp
                   (car value-exp)
                   machine
                   labels))))
      (lambda ()    ;; execution procedure for assign
         (set-contents!  target (value-proc))
         (advance-pc pc)))))


;; instruction selectors
(define (assgin-reg-name assign-instructions)
  (cadr assgin-instruction))

(define (assign-value-exp assign-instruction)
   (cddr assgin-instruction))

(define (advance-pc pc)
   (set-contents! pc (cdr (get-contents pc))))



;; Test, branch, and goto instructions
(define 
  (make-test
    inst machine labels operations flag pc)
    (let ((condition (test-condition inst)))
      (if (operations-exp? condition)
          (let ((condition-proc
                  (make-operation-exp
                   condition
                   machine
                   labels
                   operations)))
            (lambda ()
               (set-contents!
                  flag (condition-proc))
               (advance-pc)))
          (error "Bad TEST instruction:
                  ASSEMBLE" inst)))

(define (test-condition test-instruction)
   (cdr test-instruction))


(define
   (make-branch
    inst machine labels flag pc)
   (let ((dest (branc-dest inst)))
      (if (label-exp? dest)
          (let ((insts 
                  (lookup-label
                     labels
                    (label-exp-label dest))))
            (lambda ()
              (if (get-contents flag)
                  (set-contents! pc insts)
                   (advance-pc))))
          (erro "Bad BRANCH instruction:
                 ASSEMBLE"
                 inst))))

(define (branch-dest branch-instruction)
   (cadr branch-instruction))


(define (make-goto inst machine labels pc)
   (let ((dest (goto-dest inst)))
      (cond ((label-exp? dest)
            (let ((insts 
                    (lookup-label
                     labels
                     (label-exp-label dest))))
               (lambda ()
                  (set-contents! pc  insts))))
           ((register-exp? dest)
            (let ((reg
                  (get-register
                  machine
                  (register-exp-reg dest))))
              (lambda ()
                 (set-contents!
                  pc
                 (get-contents reg)))))
           (else (error "Bad GOTO instruction: ASSEMBLE"
                        inst)))))


;; other instructions
(define (make-save inst machine stack pc)
   (let ((reg (get-register
              machine
              (stack-inst-reg-name inst))))
     (lambda ()
        (push stack (get-contents reg))
        (advance-pc pc))))


(define (make-restore inst machine stack pc)
   (let ((reg (get-register
               machine
              (stack-inst-reg-name inst))))
     (lambda ()
        (set-contents! reg (pop stack))
        (advance-pc))))


(define (stack-inst-reg-name stack-instruction)
   (cadr stack-instruction))

(define (make-perform
          inst machine labels operations pc)
  (let ((action (perform-action inst)))
    (if (operation-exp? action)
        (let ((action-proc 
                 (make-operation-exp
                  action
                  machine
                  labels
                  operations)))
          (lambda ()
             (action-proc)
             (advance-pc)))
       (error "Bad PERFORM instructioin: ASSEMBLE"
              inst))))


;; Execution procedures for subexpressions
(define (make-primitive-exp exp machine labels)
   (cond ((constant-exp? exp)
         (let ((c (constant-exp-value exp)))
           (lambda () c )))
         ((label-exp? exp)
          (let ((insts
                (lookup-label
                 labels
                (label-exp-label exp))))
            (lambda () insts)))
        ((register-exp? exp)
        (let ((r (get-register
                 machine
                (register-exp-reg exp))))
          (lambda () (get-contents r))))
       (else (error "Unknow expression type: ASSEMBLE"
                     exp))))


(define (register-exp? exp)
   (tagged-list? exp 'reg))
(define (register-exp-reg exp)
   (cadr exp))
(define (constant-exp? exp)
   (tagged-list? exp 'const))
(define (constant-exp-value exp)
   (cadr exp))
(define (label-exp? exp)
   (tagged-list? exp 'label))
(define (label-exp-label exp)
   (cadr exp))


(define 
  (make-operation-exp 
      exp machine labels operations)
   (let ((op (lookup-prim
               (operation-exp-op exp)
               operations))
        (aprocs
          (map (lambad (e)
                 (make-primitive-exp
                   e machine labels))
               (operation-exp-operands exp))))
      (lambda () (apply op (map (lambda (p) (p))
                                 aprocs)))))


(define (operation-exp? exp)
   (and (pair? exp)
        (tagged-list? (car exp) 'op)))
(define (operation-exp-op operation-exp)
   (cadr (car operation-exp)))
(define (operation-exp-operands operation-exp)
   (cdr operation-exp))


(define (lookup-prim symbol operations)
  (let ((val (assoc symbol operations)))
    (if val
        (cadr val)
        (error "Unknow operation: ASSEMBLE"
              symbol))))


(define (tagged-list? exp symbol)
   (eq? (car exp) symbl))

