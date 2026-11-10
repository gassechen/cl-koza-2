(in-package #:cl-koza-ii.tests)

(in-suite cl-koza-ii-tests)

(test evaluate-adf-program-terminal-bindings
  (let ((program (make-adf-program
                  :adfs nil
                  :rpb '(and d0 (or d1 d2)))))
    (is (eq t (evaluate-adf-program
               program
               :environment '((d0 . t) (d1 . nil) (d2 . t)))))
    (is (null (evaluate-adf-program
               program
               :environment '((d0 . nil) (d1 . t) (d2 . t)))))))

(test evaluate-adf-program-calls-adfs
  (let ((program (make-adf-program
                  :adfs '((and arg0 arg1)
                          (or (adf0 arg0 arg1) arg2))
                  :rpb '(adf1 d0 d1 d2))))
    (is (null (evaluate-adf-program
               program
               :environment '((d0 . t) (d1 . nil) (d2 . nil)))))
    (is (eq t (evaluate-adf-program
               program
               :environment '((d0 . t) (d1 . t) (d2 . nil)))))
    (is (eq t (evaluate-adf-program
               program
               :environment '((d0 . nil) (d1 . nil) (d2 . t)))))))

(test evaluate-adf-program-hierarchical-three-adfs
  (let ((program (make-adf-program
                  :adfs '((or arg0 arg1)
                          (and (adf0 arg0 arg1) arg2)
                          (not (and (adf0 arg0 arg1) arg2)))
                  :rpb '(adf2 d0 d1 d2))))
    (is (null (evaluate-adf-program
               program
               :environment '((d0 . t) (d1 . t) (d2 . t)))))
    (is (eq t (evaluate-adf-program
               program
               :environment '((d0 . t) (d1 . t) (d2 . nil)))))
    (is (eq t (evaluate-adf-program
               program
               :environment '((d0 . nil) (d1 . nil) (d2 . nil)))))))

(test evaluate-adf-branch-uses-environment
  (let ((program (make-adf-program
                  :adfs '((and arg0 arg1))
                  :rpb 'arg0)))
    (is (eq t (evaluate-adf-branch
               program :adf0
               :environment '((arg0 . t) (arg1 . t)))))
    (is (null (evaluate-adf-branch
               program :adf0
               :environment '((arg0 . t) (arg1 . nil)))))))

(test evaluate-adf-tree-special-forms
  (let ((program (make-adf-program
                  :adfs nil
                  :rpb '(if d0 (progn d1 d2) d3))))
    (is (eq :yes (evaluate-adf-program
                  program
                  :environment '((d0 . t) (d1 . :ignored)
                                 (d2 . :yes) (d3 . :no)))))
    (is (eq :no (evaluate-adf-program
                 program
                 :environment '((d0 . nil) (d1 . :ignored)
                                (d2 . :yes) (d3 . :no)))))))

(test evaluate-adf-program-unbound-terminal-signals-error
  (let ((program (make-adf-program :adfs nil :rpb 'd0)))
    (signals error
      (evaluate-adf-program program :environment nil))))

(test evaluate-adf-program-missing-adf-signals-error
  (let ((program (make-adf-program :adfs nil :rpb '(adf0 d0))))
    (signals error
      (evaluate-adf-program program :environment '((d0 . t))))))
