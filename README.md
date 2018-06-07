# Machine
A Register-Machine Simulator implemented in Scheme

## what is a Register-Machine(Simulator)
A Register-Machine consists of servral parts:
1. Registers
2. instruction-set consists of basic operations, such as "assign", "test", "branch","goto", "perform"...to realize certain
functions


        (assign ⟨register-name⟩ 
                (op ⟨operation-name⟩) 
                ⟨input₁⟩ … ⟨inputₙ⟩)
        (perform (op ⟨operation-name⟩) 
                 ⟨input₁⟩ 
                 … 
                 ⟨inputₙ⟩)
        (test (op ⟨operation-name⟩) 
              ⟨input₁⟩ 
              … 
              ⟨inputₙ⟩)
        (branch (label ⟨label-name⟩))
        (goto (label ⟨label-name⟩))
      
      
3. stack, to implement recursive procedures, Subroutines

4. Machine Interface, such as 

        (define (start machine) (machine 'start))

        (define (get-register-contents machine register-name)
           (get-contents (get-register machine register-name)))

        (define (set-register-contents! machine register-name value)
           (set-contents!(get-register machine register-name) value) 'done)

5. Assembler
Our assembler is able to interpreter register-level machine language, translate it into corresponding Scheme lambda procedures




             ((perform (op user-print) (reg val))    =>	 #[compound-procedure 12])   ;;lambda expressions

             ((goto (label read-eval-print-loop))    =>  #[compound-procedure 13])   ;;lambda expressions

             ((test (op self-evaluating?) (reg exp)) =>	 #[compound-procedure 14])   ;;lambda expressions

             ((branch (label ev-self-eval))          =>  #[compound-procedure 15])   ;;lambda expressions

             ((test (op variable?) (reg exp))        =>  #[compound-procedure 16])   ;;lambda expressions

             ((branch (label ev-variable))           =>  #[compound-procedure 17])   ;;lambda expressions

              .......

      
Notice that these lambda expressions are all with only formal arguments waiting to be feed into real value, which would 
not happedn until we *Start Machine* 


## A simple case- To realize a simple Machine which is capable of computing max common factor of two numbers.


                (define gcd-machine
                  (make-machine
                   '(a b t)
                   (list (list 'rem remainder) (list '= =))
                   '(test-b
                       (test (op =) (reg b) (const 0))
                       (branch (label gcd-done))
                       (assign t (op rem) (reg a) (reg b))
                       (assign a (reg b))
                       (assign b (reg t))
                       (goto (label test-b))
                     gcd-done)))
                     
step1. to make a new machine:

 
