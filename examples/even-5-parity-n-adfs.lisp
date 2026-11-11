(defpackage #:cl-koza-2.examples.even-5-parity-n-adfs
  (:use #:cl
        #:cl-koza-2)
  (:export
   #:*number-of-adfs*
   #:even-5-parity-n-adfs
   #:run
   #:run-example
   #:verify-known-program))

(in-package #:cl-koza-2.examples.even-5-parity-n-adfs)

(defparameter *number-of-adfs* 4)

(defvar d0)
(defvar d1)
(defvar d2)
(defvar d3)
(defvar d4)

(defun nand (a b)
  (not (and a b)))

(defun nor (a b)
  (not (or a b)))

(defun odd-parity (&rest args)
  (let ((result nil))
    (dolist (value args result)
      (when value
        (setf result (not result))))))

(defun adf-symbol (index)
  (intern (format nil "ADF~D" index)
          (find-package '#:cl-koza-2.examples.even-5-parity-n-adfs)))

(defun adf-function-set (index)
  (append '(and or nand nor)
          (loop for previous below index
                collect (adf-symbol previous))))

(defun adf-argument-map (index)
  (append (make-list 4 :initial-element 2)
          (make-list index :initial-element 3)))

(defun rpb-function-set (number-of-adfs)
  (append '(and or nand nor)
          (loop for index below number-of-adfs
                collect (adf-symbol index))))

(defun rpb-argument-map (number-of-adfs)
  (append (make-list 4 :initial-element 2)
          (make-list number-of-adfs :initial-element 3)))

(defun define-terminal-set-for-adf ()
  (values '(arg0 arg1 arg2)))

(defun define-terminal-set-for-rpb ()
  (values '(d4 d3 d2 d1 d0)))

(defun make-adf-branch-spec (index)
  (make-branch-spec
   :function-set-creator
   (lambda ()
     (values (adf-function-set index)
             (adf-argument-map index)))
   :terminal-set-creator 'define-terminal-set-for-adf))

(defun make-rpb-branch-spec (number-of-adfs)
  (make-branch-spec
   :function-set-creator
   (lambda ()
     (values (rpb-function-set number-of-adfs)
             (rpb-argument-map number-of-adfs)))
   :terminal-set-creator 'define-terminal-set-for-rpb))

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

(defun evaluate-standardized-fitness-for-even-5-parity (program fitness-cases)
  (let ((raw-fitness 0.0)
        (hits 0))
    (dotimes (index *number-of-fitness-cases*)
      (let* ((fitness-case (aref fitness-cases index))
             (value-from-program
               (evaluate-adf-program
                program
                :environment
                (list (cons 'd0 (even-5-parity-fitness-case-d0 fitness-case))
                      (cons 'd1 (even-5-parity-fitness-case-d1 fitness-case))
                      (cons 'd2 (even-5-parity-fitness-case-d2 fitness-case))
                      (cons 'd3 (even-5-parity-fitness-case-d3 fitness-case))
                      (cons 'd4 (even-5-parity-fitness-case-d4 fitness-case)))))
             (target-value (even-5-parity-fitness-case-target fitness-case))
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

(defun even-5-parity-n-adfs (&optional (number-of-adfs *number-of-adfs*))
  (unless (and (integerp number-of-adfs)
               (not (minusp number-of-adfs)))
    (error "Number-of-ADFs must be a non-negative integer, not ~S."
           number-of-adfs))
  (values (loop for index below number-of-adfs
                collect (make-adf-branch-spec index))
          (make-rpb-branch-spec number-of-adfs)
          'define-fitness-cases-for-even-5-parity
          'evaluate-standardized-fitness-for-even-5-parity
          'define-parameters-for-even-5-parity
          'define-termination-criterion-for-even-5-parity))

(defun run (maximum-generations size-of-population seed
            &key (number-of-adfs *number-of-adfs*) verbose)
  (let ((*verbose* verbose)
        (*number-of-adfs* number-of-adfs))
    (run-adf-system 'even-5-parity-n-adfs
                    seed
                    maximum-generations
                    size-of-population)))

(defun run-example (&key
                      (number-of-adfs *number-of-adfs*)
                      (maximum-generations 51)
                      (size-of-population 4000)
                      (seed 1.0)
                      (verbose nil))
  (run maximum-generations
       size-of-population
       seed
       :number-of-adfs number-of-adfs
       :verbose verbose))

(defun known-adf-body (index)
  (case index
    (0 '(or (and arg0 arg1)
            (and (nand arg0 arg0) (nand arg1 arg1))))
    (1 '(nand (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1)))
              (or (and arg0 arg1)
                  (and (nand arg0 arg0) (nand arg1 arg1)))))
    (otherwise
     (list (adf-symbol (1- index)) 'arg0 'arg1 'arg2))))

(defun make-known-program (number-of-adfs)
  (make-adf-program
   :adfs (loop for index below number-of-adfs
               collect (known-adf-body index))
   :rpb (list (adf-symbol (1- number-of-adfs))
              '(adf0 (adf0 d0 d1 d0) (adf0 d2 d3 d0) d0)
              'd4
              'd0)))

(defun verify-known-program (&optional (number-of-adfs *number-of-adfs*))
  (assert (>= number-of-adfs 2) (number-of-adfs)
          "The known program requires at least two ADFs.")
  (define-parameters-for-even-5-parity)
  (let* ((fitness-cases (define-fitness-cases-for-even-5-parity))
         (program (make-known-program number-of-adfs)))
    (multiple-value-bind (fitness hits)
        (evaluate-standardized-fitness-for-even-5-parity program
                                                         fitness-cases)
      (format t "~&Known program with ~D ADF~:P: ~
                 standardized-fitness=~D hits=~D~%"
              number-of-adfs fitness hits)
      (values (zerop fitness)
              (= hits *number-of-fitness-cases*)))))
