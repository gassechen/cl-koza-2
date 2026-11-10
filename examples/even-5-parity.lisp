(defpackage #:cl-koza-ii.examples.even-5-parity
  (:use #:cl
        #:cl-koza-ii)
  (:export
   #:even-5-parity
   #:run
   #:run-example
   #:verify-known-program))

(in-package #:cl-koza-ii.examples.even-5-parity)

(defvar d0)
(defvar d1)
(defvar d2)
(defvar d3)
(defvar d4)
(defvar arg0)
(defvar arg1)
(defvar arg2)
(defvar *adf0*)
(defvar *adf1*)

(defun adf0 (arg0 arg1 arg2)
  (declare (ignorable arg2))
  (eval *adf0*))

(defun adf1 (arg0 arg1 arg2)
  (declare (ignorable arg2))
  (eval *adf1*))

(defun nand (a b)
  (not (and a b)))

(defun nor (a b)
  (not (or a b)))

(defun odd-parity (&rest args)
  (let ((result nil))
    (dolist (value args result)
      (when value
        (setf result (not result))))))

(defun define-terminal-set-for-even-5-parity-adf0 ()
  (values '(arg0 arg1 arg2)))

(defun define-terminal-set-for-even-5-parity-adf1 ()
  (values '(arg0 arg1 arg2)))

(defun define-terminal-set-for-even-5-parity-rpb ()
  (values '(d4 d3 d2 d1 d0)))

(defun define-function-set-for-even-5-parity-adf0 ()
  (values '(and or nand nor)
          '(2 2 2 2)))

(defun define-function-set-for-even-5-parity-adf1 ()
  (values '(and or nand nor adf0)
          '(2 2 2 2 3)))

(defun define-function-set-for-even-5-parity-rpb ()
  (values '(and or nand nor adf0 adf1)
          '(2 2 2 2 3 3)))

(defstruct even-5-parity-fitness-case
  d0
  d1
  d2
  d3
  d4
  target)

(defun define-fitness-cases-for-even-5-parity ()
  (let ((fitness-cases (make-array *number-of-fitness-cases*))
        (index 0))
    (dolist (d4 '(t nil))
      (dolist (d3 '(t nil))
        (dolist (d2 '(t nil))
          (dolist (d1 '(t nil))
            (dolist (d0 '(t nil))
              (let ((fitness-case (make-even-5-parity-fitness-case)))
                (setf (even-5-parity-fitness-case-d0 fitness-case) d0)
                (setf (even-5-parity-fitness-case-d1 fitness-case) d1)
                (setf (even-5-parity-fitness-case-d2 fitness-case) d2)
                (setf (even-5-parity-fitness-case-d3 fitness-case) d3)
                (setf (even-5-parity-fitness-case-d4 fitness-case) d4)
                (setf (even-5-parity-fitness-case-target fitness-case)
                      (not (odd-parity d4 d3 d2 d1 d0)))
                (setf (aref fitness-cases index) fitness-case)
                (incf index)))))))
    (values fitness-cases)))

(defun even-5-parity-wrapper (result-from-program)
  (values result-from-program))

(defun evaluate-standardized-fitness-for-even-5-parity (program fitness-cases)
  (let ((rpb (adf-program-rpb program))
        (*adf0* (adf-program-adf0 program))
        (*adf1* (adf-program-adf1 program))
        (raw-fitness 0.0)
        (hits 0))
    (dotimes (index *number-of-fitness-cases*)
      (let* ((fitness-case (aref fitness-cases index))
             (d0 (even-5-parity-fitness-case-d0 fitness-case))
             (d1 (even-5-parity-fitness-case-d1 fitness-case))
             (d2 (even-5-parity-fitness-case-d2 fitness-case))
             (d3 (even-5-parity-fitness-case-d3 fitness-case))
             (d4 (even-5-parity-fitness-case-d4 fitness-case))
             (target-value (even-5-parity-fitness-case-target fitness-case))
             (value-from-program
               (even-5-parity-wrapper (eval rpb)))
             (match-found (eq target-value value-from-program)))
        (incf raw-fitness (if match-found 1.0 0.0))
        (when match-found
          (incf hits))))
    (values (- *number-of-fitness-cases* raw-fitness)
            hits)))

(defun define-parameters-for-even-5-parity ()
  (setf *number-of-fitness-cases* 32)
  (setf *max-depth-for-new-individuals* 5)
  (setf *max-depth-for-new-subtrees-in-mutants* 4)
  (setf *max-depth-for-individuals-after-crossover* 17)
  (setf *fitness-proportionate-reproduction-fraction* 0.1)
  (setf *crossover-at-any-point-fraction* 0.2)
  (setf *crossover-at-function-point-fraction* 0.7)
  (setf *method-of-selection* :tournament)
  (setf *tournament-size* 7)
  (setf *method-of-generation* :ramped-half-and-half)
  (values))

(defun define-termination-criterion-for-even-5-parity
    (current-generation
     maximum-generations
     best-standardized-fitness
     best-hits)
  (declare (ignore best-standardized-fitness))
  (values (or (>= current-generation maximum-generations)
              (>= best-hits *number-of-fitness-cases*))))

(defun even-5-parity ()
  (values 'define-function-set-for-even-5-parity-adf0
          'define-function-set-for-even-5-parity-adf1
          'define-function-set-for-even-5-parity-rpb
          'define-terminal-set-for-even-5-parity-adf0
          'define-terminal-set-for-even-5-parity-adf1
          'define-terminal-set-for-even-5-parity-rpb
          'define-fitness-cases-for-even-5-parity
          'evaluate-standardized-fitness-for-even-5-parity
          'define-parameters-for-even-5-parity
          'define-termination-criterion-for-even-5-parity))

(defun run (maximum-generations size-of-population seed &key verbose)
  (let ((*verbose* verbose))
    (run-genetic-programming-system 'even-5-parity
                                    seed
                                    maximum-generations
                                    size-of-population)))

(defun run-example (&key
                      (maximum-generations 51)
                      (size-of-population 4000)
                      (seed 1.0)
                      (verbose nil))
  (run maximum-generations size-of-population seed :verbose verbose))

(defun verify-known-program ()
  "Evaluates the known correct program from appendix E.  Returns true
   when it solves all 32 fitness cases."
  (define-parameters-for-even-5-parity)
  (let* ((fitness-cases (define-fitness-cases-for-even-5-parity))
         (program
           (make-adf-program
            :adf0 '(or (and arg0 arg1)
                       (and (nand arg0 arg0) (nand arg1 arg1)))
            :adf1 '(nand (or (and arg0 arg1)
                             (and (nand arg0 arg0) (nand arg1 arg1)))
                         (or (and arg0 arg1)
                             (and (nand arg0 arg0) (nand arg1 arg1))))
            :rpb '(adf1 (adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
                        d4 d0))))
    (multiple-value-bind (fitness hits)
        (evaluate-standardized-fitness-for-even-5-parity program
                                                         fitness-cases)
      (format t "~&Known program: standardized-fitness=~D hits=~D~%"
              fitness hits)
      (values (zerop fitness)
              (= hits *number-of-fitness-cases*)))))
