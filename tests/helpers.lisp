(in-package #:cl-koza-2.tests)

(defmacro with-seed ((seed) &body body)
  `(let ((*seed* (coerce ,seed 'double-float)))
     ,@body))

(defmacro with-kernel-defaults (&body body)
  `(let ((*number-of-fitness-cases* 32)
         (*max-depth-for-new-individuals* 5)
         (*max-depth-for-new-subtrees-in-mutants* 4)
         (*max-depth-for-individuals-after-crossover* 17)
         (*fitness-proportionate-reproduction-fraction* 0.1)
         (*crossover-at-any-point-fraction* 0.2)
         (*crossover-at-function-point-fraction* 0.7)
         (*method-of-selection* :tournament)
         (*tournament-size* 7)
         (*method-of-generation* :ramped-half-and-half)
         (*best-of-run-individual* nil)
         (*generation-of-best-of-run-individual* 0)
         (*verbose* nil))
     ,@body))

(defmacro capture-output (&body body)
  `(with-output-to-string (*standard-output*)
     ,@body))

(defparameter *adf0-function-set* '(and or nand nor))
(defparameter *adf0-argument-map* '(2 2 2 2))
(defparameter *adf0-terminal-set* '(arg0 arg1 arg2))

(defparameter *adf1-function-set* '(and or nand nor adf0))
(defparameter *adf1-argument-map* '(2 2 2 2 3))
(defparameter *adf1-terminal-set* '(arg0 arg1 arg2))

(defparameter *rpb-function-set* '(and or nand nor adf0 adf1))
(defparameter *rpb-argument-map* '(2 2 2 2 3 3))
(defparameter *rpb-terminal-set* '(d0 d1 d2 d3 d4))

(defun create-test-population (size &key seeded-programs)
  (create-population size
                     *adf0-function-set* *adf0-argument-map*
                     *adf0-terminal-set*
                     *adf1-function-set* *adf1-argument-map*
                     *adf1-terminal-set*
                     *rpb-function-set* *rpb-argument-map*
                     *rpb-terminal-set*
                     seeded-programs))

(defun program-body-list (program)
  (list (adf-program-adf0 program)
        (adf-program-adf1 program)
        (adf-program-rpb program)))

(defun program-depth (program)
  (apply #'max (mapcar #'max-depth-of-tree (program-body-list program))))

(defun tree-symbols (tree)
  (if (consp tree)
      (cons (car tree)
            (loop for child in (cdr tree)
                  append (tree-symbols child)))
      (list tree)))

(defun symbol-names (symbols)
  (mapcar #'symbol-name symbols))

(defun symbol-by-name (name symbols)
  (find name symbols :key #'symbol-name :test #'string=))

(defun valid-tree-p (tree function-set argument-map terminal-set
                     &optional (depth 1) (maximum-depth most-positive-fixnum))
  (cond
    ((> depth maximum-depth) nil)
    ((consp tree)
     (let* ((function (car tree))
            (arguments (cdr tree))
            (position (position (symbol-name function)
                                function-set
                                :key #'symbol-name
                                :test #'string=)))
       (and position
            (= (length arguments) (nth position argument-map))
            (every (lambda (argument)
                     (valid-tree-p argument function-set argument-map
                                   terminal-set (1+ depth) maximum-depth))
                   arguments))))
    (t
     (member (symbol-name tree) terminal-set
             :key #'symbol-name :test #'string=))))

(defun valid-adf-program-p (program maximum-depth)
  (and (valid-tree-p (adf-program-adf0 program)
                     *adf0-function-set* *adf0-argument-map*
                     *adf0-terminal-set* 1 maximum-depth)
       (valid-tree-p (adf-program-adf1 program)
                     *adf1-function-set* *adf1-argument-map*
                     *adf1-terminal-set* 1 maximum-depth)
       (valid-tree-p (adf-program-rpb program)
                     *rpb-function-set* *rpb-argument-map*
                     *rpb-terminal-set* 1 maximum-depth)))

(defun all-programs-valid-p (population maximum-depth)
  (loop for index below (length population)
        always (valid-adf-program-p
                (individual-program (aref population index))
                maximum-depth)))

(defun normalized-fitness-sum (population)
  (loop for index below (length population)
        sum (individual-normalized-fitness (aref population index))))

(defun population-programs (population)
  (loop for index below (length population)
        collect (individual-program (aref population index))))

(defun known-correct-even-5-parity-program ()
  (multiple-value-bind (adf0-function-set-creator
                        adf1-function-set-creator
                        rpb-function-set-creator
                        adf0-terminal-set-creator
                        adf1-terminal-set-creator
                        rpb-terminal-set-creator
                        fitness-cases-creator
                        fitness-function
                        parameter-definer
                        termination-predicate)
      (cl-koza-2.examples.even-5-parity:even-5-parity)
    (declare (ignore adf1-terminal-set-creator
                     fitness-cases-creator
                     fitness-function
                     parameter-definer
                     termination-predicate))
    (let* ((adf0-functions (funcall adf0-function-set-creator))
           (adf1-functions (funcall adf1-function-set-creator))
           (rpb-functions (funcall rpb-function-set-creator))
           (adf0-terminals (funcall adf0-terminal-set-creator))
           (rpb-terminals (funcall rpb-terminal-set-creator))
           (and-symbol (symbol-by-name "AND" adf0-functions))
           (or-symbol (symbol-by-name "OR" adf0-functions))
           (nand-symbol (symbol-by-name "NAND" adf0-functions))
           (adf0-symbol (symbol-by-name "ADF0" adf1-functions))
           (adf1-symbol (symbol-by-name "ADF1" rpb-functions))
           (arg0 (symbol-by-name "ARG0" adf0-terminals))
           (arg1 (symbol-by-name "ARG1" adf0-terminals))
           (d0 (symbol-by-name "D0" rpb-terminals))
           (d1 (symbol-by-name "D1" rpb-terminals))
           (d2 (symbol-by-name "D2" rpb-terminals))
           (d3 (symbol-by-name "D3" rpb-terminals))
           (d4 (symbol-by-name "D4" rpb-terminals))
           (or-branch (list or-symbol
                            (list and-symbol arg0 arg1)
                            (list and-symbol
                                  (list nand-symbol arg0 arg0)
                                  (list nand-symbol arg1 arg1)))))
      (make-adf-program
       :adf0 or-branch
       :adf1 (list nand-symbol or-branch or-branch)
       :rpb (list adf1-symbol
                  (list adf0-symbol
                        (list adf0-symbol d0 d1 d0)
                        (list adf0-symbol d2 d3 d0)
                        d0)
                  d4
                  d0)))))

(defun even-5-parity-problem (&key parameter-overrides
                                   termination-override
                                   fitness-override)
  (lambda ()
    (multiple-value-bind (adf0-function-set-creator
                          adf1-function-set-creator
                          rpb-function-set-creator
                          adf0-terminal-set-creator
                          adf1-terminal-set-creator
                          rpb-terminal-set-creator
                          fitness-cases-creator
                          fitness-function
                          parameter-definer
                          termination-predicate)
        (cl-koza-2.examples.even-5-parity:even-5-parity)
      (values adf0-function-set-creator
              adf1-function-set-creator
              rpb-function-set-creator
              adf0-terminal-set-creator
              adf1-terminal-set-creator
              rpb-terminal-set-creator
              fitness-cases-creator
              (or fitness-override fitness-function)
              (lambda ()
                (funcall parameter-definer)
                (loop for (name . value) in parameter-overrides
                      do (setf (symbol-value name) value)))
              (or termination-override termination-predicate)))))

(defun run-with-overrides (seed maximum-generations size-of-population
                           &key parameter-overrides
                                termination-override
                                fitness-override
                                seeded-programs)
  (let ((problem (even-5-parity-problem
                  :parameter-overrides parameter-overrides
                  :termination-override termination-override
                  :fitness-override fitness-override)))
    (apply #'run-genetic-programming-system
           problem seed maximum-generations size-of-population
           seeded-programs)))

(defun constant-fitness (program fitness-cases)
  (declare (ignore program fitness-cases))
  (values 0 0))

(defun make-test-individual (program &key
                                     (standardized-fitness 0)
                                     (adjusted-fitness 0)
                                     (normalized-fitness 0)
                                     (hits 0))
  (make-individual :program program
                   :standardized-fitness standardized-fitness
                   :adjusted-fitness adjusted-fitness
                   :normalized-fitness normalized-fitness
                   :hits hits))
